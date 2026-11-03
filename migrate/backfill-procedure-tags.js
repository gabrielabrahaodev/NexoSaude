#!/usr/bin/env node
'use strict';
// Dry-run by default. No embedded credentials, deletes or financial writes.
const fs = require('node:fs');
const path = require('node:path');
function templateData(procedure, id) {
  return {schemaVersion: 1, clinicId: procedure.clinicId, procedureId: id, name: procedure.name || 'Procedimento', category: procedure.category || 'Geral', active: procedure.active !== false, procedureSnapshot: procedure};
}
function instanceData({clinicId, patientId, patientName, budgetId, planId, index, line, definition, planItem = {}, planStatus}) {
  const done = ['completed', 'concluido', 'concluído', 'finalizado', 'done'].includes(String(planItem.status || '').toLowerCase());
  const closed = String(planStatus || '').toLowerCase() !== 'active';
  return {schemaVersion: 1, clinicId, patientId, patientName: patientName || '', budgetId, planId, lineIndex: index,
    procedureId: String(line.id || line.procedureId || ''), name: line.name || definition.name || 'Procedimento', category: definition.category || 'Geral', agreedValue: line.price ?? line.subtotal ?? null, quantity: line.quantity ?? 1, region: line.region ?? null, lineSnapshot: line, definitionSnapshot: definition,
    status: done ? 'completed' : closed ? 'legacy_closed' : 'pending', sessionCount: 0, migrated: true};
}
function approved(b) { return ['aprovado', 'approved'].includes(String(b.status || '').toLowerCase()); }
async function main() {
  const args = process.argv.slice(2);
  const value = name => { const i = args.indexOf(name); return i < 0 ? '' : args[i + 1] || ''; };
  const project = value('--project'), clinic = value('--clinic'), credential = value('--credential');
  const apply = args.includes('--apply');
  if (!project || !clinic || clinic.includes('/') || !credential) throw Error('Uso: node migrate/backfill-procedure-tags.js --project PROJETO --clinic CLINICA --credential CAMINHO_JSON [--apply --confirm PROJETO:CLINICA]');
  const key = JSON.parse(fs.readFileSync(credential, 'utf8'));
  if (key.project_id !== project) throw Error('A credencial pertence a outro projeto.');
  if (apply && value('--confirm') !== `${project}:${clinic}`) throw Error('APPLY exige --confirm PROJETO:CLINICA.');
  const admin = require('firebase-admin');
  const app = admin.initializeApp({credential: admin.credential.cert(key), projectId: project});
  const db = app.firestore();
  try {
    const clinicDoc = await db.collection('clinics').doc(clinic).get();
    if (!clinicDoc.exists) throw Error('Clínica inexistente.');
    const [procedures, budgets, plans] = await Promise.all(['procedures','budgets','treatment_plans'].map(c => db.collection(c).where('clinicId','==',clinic).get()));
    const definitions = new Map(procedures.docs.map(d => [d.id, templateData(d.data(), d.id)]));
    const operations = [], skipped = [];
    for (const p of procedures.docs) {
      const ref = p.ref.collection('tags').doc('definition');
      if (!(await ref.get()).exists) operations.push({kind: 'template', path: ref.path, source: p.id});
    }
    for (const b of budgets.docs.filter(d => approved(d.data()))) {
      const data = b.data();
      const linked = plans.docs.filter(p => p.id === data.relatedPlanId || p.data().budgetId === b.id);
      if (linked.length !== 1 || linked[0].data().patientId !== data.patientId) { skipped.push({budgetId: b.id, reason: 'Plano ausente, ambíguo ou paciente divergente'}); continue; }
      const parent = await db.collection('patients').doc(String(data.patientId)).get();
      if (parent.data()?.clinicId !== clinic) { skipped.push({budgetId: b.id, reason: 'Paciente fora da clínica'}); continue; }
      const lines = Array.isArray(data.items) ? data.items : [];
      const planItems = linked[0].data().items || [];
      for (let index = 0; index < lines.length; index++) {
        if (!planItems[index] || String(planItems[index].name || '') !== String(lines[index].name || '')) { skipped.push({budgetId: b.id, index, reason: 'Linha não coincide com a etapa do plano'}); continue; }
        const ref = parent.ref.collection('procedure_tags').doc(`budget_${b.id}_line_${index}`);
        if (!(await ref.get()).exists) operations.push({kind: 'patient', path: ref.path, budgetId: b.id, planId: linked[0].id, patientId: parent.id, index});
      }
    }
    const manifest = {project, clinic, apply, createdAt: new Date().toISOString(), operations: operations.map(o => ({...o, before: null})), skipped};
    const dir = path.resolve(value('--output') || 'tag-migration-backups');
    fs.mkdirSync(dir, {recursive: true});
    const filename = path.join(dir, `tags-${Date.now()}-${apply ? 'apply' : 'dry-run'}.json`);
    fs.writeFileSync(filename, JSON.stringify(manifest, null, 2), {flag: 'wx', mode: 0o600});
    console.log(JSON.stringify({mode: apply ? 'APPLY' : 'DRY-RUN', planned: operations.length, skipped: skipped.length, manifest: filename}));
    if (!apply) return;
    let created = 0;
    for (const op of operations) {
      const didCreate = await db.runTransaction(async tx => {
        const ref = db.doc(op.path);
        if ((await tx.get(ref)).exists) return false; // Never overwrite status/history.
        if (op.kind === 'template') {
          const p = await tx.get(db.collection('procedures').doc(op.source));
          if (p.data()?.clinicId !== clinic) throw Error('Procedimento mudou de clínica.');
          tx.create(ref, {...templateData(p.data(), p.id), updatedAt: admin.firestore.FieldValue.serverTimestamp()});
        } else {
          const [b, p, patient] = await Promise.all([tx.get(db.collection('budgets').doc(op.budgetId)), tx.get(db.collection('treatment_plans').doc(op.planId)), tx.get(db.collection('patients').doc(op.patientId))]);
          const budget = b.data(), plan = p.data();
          if (patient.data()?.clinicId !== clinic || budget?.clinicId !== clinic || plan?.clinicId !== clinic || budget.patientId !== op.patientId || plan.patientId !== op.patientId || !approved(budget) || !(budget.relatedPlanId === p.id || plan.budgetId === b.id)) throw Error('Contexto da migração alterado; reexecute dry-run.');
          const line = budget.items?.[op.index], item = plan.items?.[op.index];
          if (!line || !item || line.name !== item.name) throw Error('Etapa alterada; reexecute dry-run.');
          tx.create(ref, {...instanceData({clinicId: clinic, patientId: op.patientId, patientName: budget.patientName, budgetId: b.id, planId: p.id, index: op.index, line, definition: definitions.get(String(line.id || '')) || {}, planItem: item, planStatus: plan.status}), createdAt: admin.firestore.FieldValue.serverTimestamp()});
        }
        return true;
      });
      if (didCreate) created++;
    }
    console.log(JSON.stringify({created, preserved: operations.length - created, manifest: filename}));
  } finally { await app.delete(); }
}
module.exports = {templateData, instanceData, approved};
if (require.main === module) main().catch(e => { console.error(e.message); process.exitCode = 1; });

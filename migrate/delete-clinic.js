// Exclusão administrativa de clínica (Firestore Admin SDK).
// READ-ONLY por padrão. Destinado a clínica bloqueada/expirada quando as
// Rules impedem a cascata pelo navegador.
// Uso:
//   node migrate/delete-clinic.js --clinic ID
//   node migrate/delete-clinic.js --clinic ID --apply --confirm-delete ID
// Requer migrate/new-key.json com permissões administrativas. NUNCA versionar
// essa credencial. O script não executa sozinho; --apply exige confirmação.
const admin = require('firebase-admin');
const serviceAccount = require('./new-key.json');

const PROJECT_ID = 'nexosaude';
const args = process.argv.slice(2);
function argValue(name) {
  const i = args.indexOf(name);
  if (i >= 0 && args[i + 1] && !args[i + 1].startsWith('--')) return args[i + 1];
  const prefix = name + '=';
  const found = args.find((a) => a.startsWith(prefix));
  return found ? found.slice(prefix.length) : null;
}
const clinicId = argValue('--clinic');
const APPLY = args.includes('--apply');
const confirmedId = argValue('--confirm-delete');

if (!serviceAccount || serviceAccount.project_id !== PROJECT_ID) {
  throw new Error('Credencial incorreta: esperado project_id ' + PROJECT_ID + '.');
}
if (!clinicId || clinicId.includes('/')) {
  throw new Error('Informe um único ID de clínica com --clinic ID.');
}
if (APPLY && confirmedId !== clinicId) {
  throw new Error('Proteção destrutiva: para aplicar, informe --confirm-delete com o MESMO ID da clínica.');
}
if (args.includes('--help') || args.includes('-h')) {
  console.log('Uso: node migrate/delete-clinic.js --clinic ID [--apply --confirm-delete ID]');
  console.log('Sem --apply é READ-ONLY. Nenhuma escrita será realizada.');
  process.exit(0);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

const OPERATIONAL_COLLECTIONS = [
  'appointments',
  'budgets',
  'treatments',
  'treatment_plans',
  'financial',
  'clinical_records',
  'lab_orders',
  'psychology_schedules',
  'expenses',
  'procedures',
  'suppliers',
  'inventory',
];

async function queryByClinic(collectionName) {
  return db.collection(collectionName)
    .where('clinicId', '==', clinicId)
    .get();
}

async function runLimited(items, limit, operation) {
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (true) {
      const index = next++;
      if (index >= items.length) return;
      await operation(items[index]);
    }
  });
  await Promise.all(workers);
}

(async () => {
  const clinicRef = db.collection('clinics').doc(clinicId);
  const clinicSnap = await clinicRef.get();
  if (!clinicSnap.exists) throw new Error('A clínica não existe: ' + clinicId);

  // PRE-FLIGHT: todas as consultas e contagens ocorrem antes de qualquer escrita.
  const [patientsSnap, usersSnap, portalByClinicSnap, ...operationalSnaps] =
    await Promise.all([
      db.collection('patients').where('clinicId', '==', clinicId).get(),
      db.collection('users').where('allowedClinics', 'array-contains', clinicId).get(),
      db.collection('portal').where('clinicId', '==', clinicId).get(),
      ...OPERATIONAL_COLLECTIONS.map(queryByClinic),
    ]);

  const patientIds = patientsSnap.docs.map((d) => d.id);
  const portalTokens = new Set(
    portalByClinicSnap.docs.map((d) => d.id),
  );
  for (const patientDoc of patientsSnap.docs) {
    const token = String((patientDoc.data() || {}).portalToken || '');
    if (token) portalTokens.add(token);
  }

  const counts = {
    clinic: 1,
    patients: patientsSnap.size,
    usersToUnlink: usersSnap.size,
    portalMirrors: portalTokens.size,
    publicClinic: (await db.collection('public_clinics').doc(clinicId).get()).exists ? 1 : 0,
    portalSlots: (await db.collection('portal_slots').doc(clinicId).get()).exists ? 1 : 0,
  };
  OPERATIONAL_COLLECTIONS.forEach((name, i) => {
    counts[name] = operationalSnaps[i].size;
  });

  console.log('Projeto: ' + PROJECT_ID);
  console.log('Clínica: ' + clinicId);
  console.log('Nome: ' + String((clinicSnap.data() || {}).name || '(sem nome)'));
  console.log('Modo: ' + (APPLY ? 'APPLY DESTRUTIVO' : 'DRY-RUN (nenhuma escrita)'));
  console.log('Documentos planejados:');
  for (const [name, count] of Object.entries(counts)) {
    console.log('  ' + name + ': ' + count);
  }
  console.log('Anamneses a verificar: ' + patientIds.length);
  console.log('Subcoleções de pacientes: docs/clinical_data serão removidas recursivamente.');
  console.log('Subcoleções da clínica: members/members_private/settings serão removidas recursivamente.');

  if (!APPLY) {
    console.log('');
    console.log('DRY-RUN: nenhum dado foi alterado.');
    console.log('Revise a clínica e os volumes antes de aplicar.');
    return;
  }

  // 1. Desvincular usuários sem apagar contas nem logins.
  const batches = [];
  let batch = db.batch();
  let pending = 0;
  for (const userDoc of usersSnap.docs) {
    const data = userDoc.data() || {};
    const current = Array.isArray(data.allowedClinics) ? data.allowedClinics : [];
    const remaining = current.map(String).filter((id) => id !== clinicId);
    batch.update(userDoc.ref, { allowedClinics: remaining });
    pending++;
    if (pending >= 400) {
      batches.push(batch.commit());
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) batches.push(batch.commit());
  await Promise.all(batches);

  // 2. Apagar espelhos de portal por token e anamnese associada ao paciente.
  const portalRefs = [...portalTokens].map((token) => db.collection('portal').doc(token));
  const anamnesisRefs = patientIds.map((id) => db.collection('anamnesis').doc(id));
  await runLimited(portalRefs, 10, (ref) => ref.delete());
  await runLimited(anamnesisRefs, 10, (ref) => ref.delete());

  // 3. Remover os registros operacionais filtrados pelo clinicId exato.
  const operationalRefs = operationalSnaps.flatMap((snap) => snap.docs.map((d) => d.ref));
  await runLimited(operationalRefs, 10, (ref) => db.recursiveDelete(ref));

  // 4. Remover pacientes recursivamente (inclui docs e clinical_data).
  await runLimited(patientsSnap.docs.map((d) => d.ref), 10, (ref) => db.recursiveDelete(ref));

  // 5. Remover espelhos públicos e slots.
  await db.recursiveDelete(db.collection('public_clinics').doc(clinicId));
  await db.collection('portal_slots').doc(clinicId).delete();

  // 6. Remover a clínica por último, recursivamente (membros/settings incluídos).
  await db.recursiveDelete(clinicRef);

  console.log('');
  console.log('EXCLUSÃO CONCLUÍDA.');
  console.log('Usuários desvinculados: ' + usersSnap.size + ' (contas mantidas).');
  console.log('Pacientes apagados recursivamente: ' + patientsSnap.size);
  console.log('Portal mirrors processados: ' + portalRefs.length);
  console.log('Revise logs e contagens do Firestore após a operação.');
})().catch((error) => {
  console.error('FALHOU:', error.message);
  process.exitCode = 1;
}).finally(async () => {
  await admin.app().delete().catch(() => {});
});

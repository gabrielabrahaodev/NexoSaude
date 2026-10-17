// Backfill de diretórios públicos mínimos e espelhos privados de equipe.
// Uso: node migrate/clinic-members-backfill.js            (dry-run)
//      node migrate/clinic-members-backfill.js --apply   (escreve)
// Requer migrate/new-key.json local (service account ignorada no git).
// NÃO altera users/{uid}. Em APPLY substitui integralmente members/{uid}
// para remover PII legada e grava o detalhe em members_private/{uid}.
const admin = require('firebase-admin');
const serviceAccount = require('./new-key.json');

if (serviceAccount.project_id !== 'nexosaude') {
  throw new Error('Credencial incorreta: esperado project_id nexosaude.');
}
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexosaude',
});
const db = admin.firestore();
const APPLY = process.argv.includes('--apply');

function publicDirectoryData(uid, user) {
  return {
    uid,
    name: user.name || '',
    role: user.role || '',
    status: user.status || '',
    createdAt: user.createdAt || admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function privateDirectoryData(uid, user, localAllowed) {
  return {
    uid,
    name: user.name || '',
    email: user.email || '',
    role: user.role || '',
    status: user.status || '',
    phone: user.phone || '',
    whatsapp: user.whatsapp || '',
    cpf: user.cpf || '',
    menuAccess: user.menuAccess && typeof user.menuAccess === 'object' &&
      !Array.isArray(user.menuAccess) ? user.menuAccess : {},
    allowedClinics: localAllowed,
    createdAt: user.createdAt || admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

(async () => {
  const [usersSnap, clinicsSnap] = await Promise.all([
    db.collection('users').get(),
    db.collection('clinics').get(),
  ]);
  const clinics = new Map(clinicsSnap.docs.map((d) => [
    d.id, { ...d.data(), id: d.id },
  ]));
  let publicPlanned = 0;
  let privatePlanned = 0;
  let skippedNoClinic = 0;
  let skippedNoOwner = 0;
  let batch = db.batch();
  let pending = 0;
  let appliedWrites = 0;

  for (const userDoc of usersSnap.docs) {
    const user = userDoc.data() || {};
    const allowed = [...new Set((Array.isArray(user.allowedClinics)
      ? user.allowedClinics : []).map((id) => String(id)))];
    if (!allowed.length) continue;

    const valid = allowed.filter((id) => clinics.has(id));
    if (!valid.length) { skippedNoClinic++; continue; }

    for (const clinicId of valid) {
      const clinic = clinics.get(clinicId);
      const ownerId = String(clinic.ownerId || '');
      if (!ownerId) { skippedNoOwner++; continue; }
      const localAllowed = valid.filter((otherId) =>
        String(clinics.get(otherId)?.ownerId || '') === ownerId).sort();
      const clinicRef = db.collection('clinics').doc(clinicId);
      const publicRef = clinicRef.collection('members').doc(userDoc.id);
      const privateRef = clinicRef.collection('members_private').doc(userDoc.id);
      publicPlanned++;
      privatePlanned++;

      if (APPLY) {
        // Substituição total intencional: remove PII legada do espelho público.
        batch.set(publicRef, publicDirectoryData(userDoc.id, user));
        batch.set(privateRef, privateDirectoryData(userDoc.id, user, localAllowed));
        pending += 2;
        appliedWrites += 2;
        if (pending >= 400) {
          await batch.commit();
          batch = db.batch();
          pending = 0;
        }
      }
    }
  }
  if (APPLY && pending) await batch.commit();

  console.log('Projeto: nexosaude');
  console.log('Modo: ' + (APPLY ? 'APPLY' : 'DRY-RUN (nenhuma escrita)'));
  console.log('Usuários analisados: ' + usersSnap.size);
  console.log('Clínicas analisadas: ' + clinicsSnap.size);
  console.log('Espelhos públicos planejados: ' + publicPlanned);
  console.log('Espelhos privados planejados: ' + privatePlanned);
  console.log('Documentos que seriam gravados: ' + (publicPlanned + privatePlanned));
  console.log('Usuários sem clínica válida: ' + skippedNoClinic);
  console.log('Vínculos sem owner de clínica: ' + skippedNoOwner);
  console.log('Documentos gravados: ' + appliedWrites);
  console.log(APPLY
    ? 'Confirme as contagens; execute novamente sem --apply para verificar estabilidade.'
    : 'DRY-RUN não grava. Revise contagens antes de usar --apply.');
  process.exit(0);
})().catch((error) => {
  console.error('FALHOU:', error.message);
  process.exit(1);
});

// Backfill de diretórios de equipe por clínica.
// Uso: node migrate/clinic-members-backfill.js            (dry-run)
//      node migrate/clinic-members-backfill.js --apply   (escreve)
// Requer migrate/new-key.json local (service account ignorada pelo Git).
// Não altera users/{uid}; só cria/atualiza a projeção de leitura por clínica.
const admin = require('firebase-admin');
const serviceAccount = require('./new-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'nexosaude',
});
const db = admin.firestore();
const APPLY = process.argv.includes('--apply');

function directoryData(uid, user, localAllowed) {
  return {
    uid,
    name: user.name || '',
    email: user.email || '',
    role: user.role || '',
    status: user.status || '',
    phone: user.phone || '',
    whatsapp: user.whatsapp || '',
    cpf: user.cpf || '',
    menuAccess: user.menuAccess && typeof user.menuAccess === 'object'
      ? user.menuAccess : {},
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
  let planned = 0;
  let skippedNoClinic = 0;
  let skippedNoOwner = 0;
  let batch = db.batch();
  let pending = 0;
  let applied = 0;

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
      const ref = db.collection('clinics').doc(clinicId)
        .collection('members').doc(userDoc.id);
      planned++;
      if (APPLY) {
        batch.set(ref, directoryData(userDoc.id, user, localAllowed), { merge: true });
        pending++;
        applied++;
        if (pending >= 400) {
          await batch.commit();
          batch = db.batch();
          pending = 0;
        }
      }
    }
  }
  if (APPLY && pending) await batch.commit();
  console.log('Modo: ' + (APPLY ? 'APPLY' : 'DRY-RUN (nenhuma escrita)'));
  console.log('Usuários analisados: ' + usersSnap.size);
  console.log('Clínicas analisadas: ' + clinicsSnap.size);
  console.log('Espelhos planejados: ' + planned);
  console.log('Usuários sem clínica válida: ' + skippedNoClinic);
  console.log('Vínculos sem owner de clínica: ' + skippedNoOwner);
  console.log('Espelhos gravados: ' + applied);
  console.log('Revise o dry-run antes de executar com --apply.');
  process.exit(0);
})().catch((error) => {
  console.error('FALHOU:', error.message);
  process.exit(1);
});

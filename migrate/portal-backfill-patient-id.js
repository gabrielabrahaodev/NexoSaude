// Backfill seguro para que espelhos antigos passem pelas novas Firestore Rules.
// Uso: node migrate/portal-backfill-patient-id.js            (dry-run)
//      node migrate/portal-backfill-patient-id.js --apply   (escreve)
// Requer migrate/new-key.json (service account local, nunca versionada).
// NÃO cria tokens, NÃO cria espelhos e NÃO muda o consentimento LGPD.
const admin = require('firebase-admin');
const sa = require('./new-key.json');
admin.initializeApp({ credential: admin.credential.cert(sa), projectId: 'nexosaude' });
const db = admin.firestore();
const APPLY = process.argv.includes('--apply');

(async () => {
  const patients = await db.collection('patients').get();
  let eligible = 0, missingMirror = 0, withoutConsent = 0, noToken = 0;
  let unchanged = 0, changed = 0, pending = 0, batch = db.batch();

  for (const patient of patients.docs) {
    const data = patient.data();
    const token = String(data.portalToken || '');
    const consent = data.lgpdPortalConsent && data.lgpdPortalConsent.accepted === true;
    const clinicId = String(data.clinicId || '');
    if (!token) { noToken++; continue; }
    if (!consent) { withoutConsent++; continue; }
    if (!clinicId) continue;
    const ref = db.collection('portal').doc(token);
    const mirror = await ref.get();
    if (!mirror.exists) { missingMirror++; continue; }
    const old = mirror.data() || {};
    if (old.patientId === patient.id && old.clinicId === clinicId) { unchanged++; continue; }
    eligible++;
    if (APPLY) {
      batch.set(ref, { patientId: patient.id, clinicId }, { merge: true });
      pending++;
      changed++;
      if (pending >= 400) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    }
  }
  if (APPLY && pending > 0) await batch.commit();
  console.log('Modo: ' + (APPLY ? 'APPLY' : 'DRY-RUN (nenhuma escrita)'));
  console.log('Pacientes analisados: ' + patients.size);
  console.log('Espelhos elegíveis: ' + eligible);
  console.log('Já corretos: ' + unchanged);
  console.log('Sem espelho existente: ' + missingMirror);
  console.log('Sem token (não recriados): ' + noToken);
  console.log('Sem aceite explícito (não alterados): ' + withoutConsent);
  console.log('Espelhos ajustados: ' + changed);
  console.log('Revise o dry-run e execute --apply antes de publicar as Rules.');
  process.exit(0);
})().catch((e) => { console.error('FALHOU:', e.message); process.exit(1); });

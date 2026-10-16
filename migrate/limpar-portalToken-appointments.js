// Limpa `portalToken` carimbado em appointments (fonte única de verdade
// passa a ser `patients/{id}.portalToken`; token copiado no agendamento
// permitia confirmar sem o link — reavaliação P1).
//
// Uso: node limpar-portalToken-appointments.js [--apply]
//   - sem --apply: só CONTA (dry-run, sem escrever).
//   - com --apply: define portalToken=null nos docs que têm o campo.
//   - usa new-key.json (service account do projeto nexosaude).
const admin = require('firebase-admin');
const sa = require('./new-key.json');

admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'nexosaude',
});
const db = admin.firestore();
const APPLY = process.argv.includes('--apply');

(async () => {
  const snap = await db.collection('appointments').get();
  let marked = 0;
  let batch = db.batch();
  let n = 0;
  for (const d of snap.docs) {
    const m = d.data();
    if (m.portalToken !== undefined && m.portalToken !== null) {
      marked++;
      if (APPLY) {
        batch.update(d.ref, { portalToken: null });
        if (++n >= 400) {
          await batch.commit();
          batch = db.batch();
          n = 0;
        }
      }
    }
  }
  if (APPLY && n > 0) await batch.commit();
  console.log(
    (APPLY ? 'LIMPO: ' : 'DRY-RUN (nada escrito): ') +
      marked +
      ' agendamentos com portalToken em ' +
      snap.size +
      ' lidos.');
  process.exit(0);
})().catch((e) => {
  console.error('FALHOU: ' + e.message);
  process.exit(1);
});

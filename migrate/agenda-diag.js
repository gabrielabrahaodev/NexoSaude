// Diagnostico da agenda: status dos agendamentos da clinica + docs sem date.
const admin = require('firebase-admin');
const sa = require('./new-key.json');

admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'nexosaude',
});
const db = admin.firestore();

(async () => {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 7);
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 14);
  const snap = await db
    .collection('appointments')
    .where('date', '>=', start)
    .where('date', '<', end)
    .limit(200)
    .get();
  const byStatus = {};
  let noDate = 0;
  let noDentist = 0;
  snap.forEach((d) => {
    const m = d.data();
    const st = String(m.status || '(sem status)');
    byStatus[st] = (byStatus[st] || 0) + 1;
    if (!m.date) noDate++;
    if (!m.dentistId) noDentist++;
  });
  console.log('docs na janela:', snap.size);
  console.log('por status:', JSON.stringify(byStatus));
  console.log('sem date:', noDate, '| sem dentistId:', noDentist);
  process.exit(0);
})().catch((e) => {
  console.error('FALHOU:', e.message);
  process.exit(1);
});

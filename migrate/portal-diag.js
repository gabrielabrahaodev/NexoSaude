// Diagnóstico do doc-espelho do portal por token.
// Uso: node portal-diag.js <token>
const admin = require('firebase-admin');
const sa = require('./new-key.json');

admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'nexosaude',
});
const db = admin.firestore();

(async () => {
  const token = (process.argv[2] || '').trim();
  if (!token) {
    console.error('Uso: node portal-diag.js <token>');
    process.exit(1);
  }
  const d = await db.collection('portal').doc(token).get();
  console.log('exists:', d.exists);
  if (!d.exists) process.exit(0);
  const m = d.data();
  console.log('keys:', Object.keys(m).join(','));
  console.log('clinic:', m.clinicId, '|', m.clinicName);
  console.log('updatedAt:', m.updatedAt && m.updatedAt.toDate ? m.updatedAt.toDate() : m.updatedAt);
  const debts = m.debts || [];
  console.log('debts:', debts.length);
  for (const x of debts) {
    console.log('  -', x.title, x.amount, '| venc:', x.dueDate && x.dueDate.toDate ? x.dueDate.toDate() : x.dueDate, '|', x.status);
  }
  const sess = m.sessions || [];
  console.log('sessions:', sess.length);
  for (const s of sess) {
    console.log('  -', s.id, '|', s.date && s.date.toDate ? s.date.toDate() : s.date, '|', s.status);
  }
  process.exit(0);
})().catch((e) => {
  console.error('FALHOU:', e.message);
  process.exit(1);
});

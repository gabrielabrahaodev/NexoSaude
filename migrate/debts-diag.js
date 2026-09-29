// Diagnóstico: espelho do portal x débitos reais de um paciente.
// Uso: node debts-diag.js <patientId>  |  node debts-diag.js -t <portalToken>
const admin = require('firebase-admin');
const sa = require('./new-key.json');

admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'nexosaude',
});
const db = admin.firestore();

(async () => {
  let pid = (process.argv[2] || '').trim();
  if (process.argv[2] === '-t') {
    const token = (process.argv[3] || '').trim();
    const q = await db.collection('patients').where('portalToken', '==', token).limit(1).get();
    if (q.empty) {
      console.error('Nenhum paciente com esse token.');
      process.exit(1);
    }
    pid = q.docs[0].id;
  }
  if (!pid) {
    console.error('Uso: node debts-diag.js <patientId> | -t <token>');
    process.exit(1);
  }
  const p = await db.collection('patients').doc(pid).get();
  const pdata = p.data() || {};
  console.log('Paciente:', pdata.name, '| token:', (pdata.portalToken || '').slice(0, 8) + '...');
  const token = pdata.portalToken || '';
  if (token) {
    const m = await db.collection('portal').doc(token).get();
    const md = m.data() || {};
    const debts = md.debts || [];
    console.log('Espelho debts:', debts.length, '| updatedAt:', md.updatedAt ? md.updatedAt.toDate() : null);
    for (const d of debts) {
      console.log('  -', d.title, d.amount, 'venc:', d.dueDate ? d.dueDate.toDate() : null, d.status);
    }
  }
  const fins = await db.collection('financial').where('patientId', '==', pid).get();
  console.log('Financial docs:', fins.size);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  let n = 0;
  fins.forEach((d) => {
    const m = d.data();
    const amount = Number(m.amount) || 0;
    const paid = Number(m.paidAmount) || 0;
    const due = m.dueDate && m.dueDate.toDate ? m.dueDate.toDate() : null;
    const st = String(m.status || '');
    const overdue = paid < amount && due && due < today;
    if (overdue) {
      n++;
      console.log('  OVERDUE:', d.id, m.title, amount, 'pago:', paid, 'venc:', due, '| status:', st, '| dueType:', m.dueDate ? m.dueDate.constructor.name : typeof m.dueDate);
    }
  });
  console.log('Overdue reais:', n);
  process.exit(0);
})().catch((e) => {
  console.error('FALHOU:', e.message);
  process.exit(1);
});

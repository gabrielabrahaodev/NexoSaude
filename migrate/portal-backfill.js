// Reconstrói TODOS os espelhos portal/{token} com a lógica atual
// (atrasos top-3, próximas 3 sessões, dentistId, clinicId).
// Replica PortalMirrorSync.patient. Uso: node migrate/portal-backfill.js
const admin = require('firebase-admin');
const sa = require('./new-key.json');

admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'nexosaude',
});
const db = admin.firestore();
const now = new Date();
const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

(async () => {
  const patients = await db.collection('patients').get();
  let ok = 0;
  for (const p of patients.docs) {
    const pdata = p.data();
    let token = pdata.portalToken || '';
    if (!token) {
      token = [...Array(32)]
        .map(() => 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'[Math.floor(Math.random() * 62)])
        .join('');
      await p.ref.update({ portalToken: token });
    }
    const appts = await db
      .collection('appointments')
      .where('patientId', '==', p.id)
      .limit(30)
      .get();
    const sessions = [];
    appts.forEach((d) => {
      const m = d.data();
      if (!m.date) return;
      sessions.push({
        id: d.id,
        date: m.date.toDate(),
        professional: String(m.dentistName || ''),
        dentistId: String(m.dentistId || ''),
        status: String(m.status || ''),
      });
    });
    const upcoming = sessions
      .filter((s) => s.date >= now)
      .sort((a, b) => a.date - b.date)
      .slice(0, 3);
    const fins = await db
      .collection('financial')
      .where('patientId', '==', p.id)
      .limit(50)
      .get();
    const open = [];
    fins.forEach((d) => {
      const m = d.data();
      const amount = Number(m.amount || 0);
      const paid = Number(m.paidAmount || 0);
      const due = m.dueDate ? m.dueDate.toDate() : null;
      if (paid < amount && due && due < today) {
        open.push({
          id: d.id,
          title: String(m.title || 'Lançamento'),
          amount,
          paidAmount: paid,
          dueDate: due,
          status: String(m.status || ''),
        });
      }
    });
    open.sort((a, b) => a.dueDate - b.dueDate);
    let pixKey = '';
    let clinicName = '';
    try {
      const c = await db.collection('clinics').doc(String(pdata.clinicId || '')).get();
      pixKey = String((c.data() || {}).pixKey || '');
      clinicName = String((c.data() || {}).name || '');
    } catch (e) {}
    let refused = [];
    try {
      const old = await db.collection('portal').doc(token).get();
      if (old.exists && Array.isArray(old.data().propostasRecusadas)) {
        refused = old.data().propostasRecusadas.map(String);
      }
    } catch (e) {}
    await db.collection('portal').doc(token).set({
      clinicId: String(pdata.clinicId || ''),
      clinicName,
      sessions: upcoming,
      debts: open.slice(0, 3),
      debtsTotal: open.reduce((s, d) => s + d.amount, 0),
      debtsCount: open.length,
      pixKey,
      propostasRecusadas: refused,
      updatedAt: new Date(),
    });
    ok++;
  }
  console.log('Espelhos reconstruídos: ' + ok + '/' + patients.size);
  process.exit(0);
})().catch((e) => {
  console.error('FALHOU:', e.message);
  process.exit(1);
});

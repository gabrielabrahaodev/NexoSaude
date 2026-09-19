// Backfill do espelho portal_slots/{clinicId} (janela de 14 dias).
// Replica PortalMirrorSync.ensureWindow (grade 08:30-20:00, slots 30min).
// Uso: node migrate/slots-backfill.js (exige cota de LEITURA ok).
const admin = require('firebase-admin');
const sa = require('./new-key.json');

admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'nexosaude',
});
const db = admin.firestore();

function grade() {
  const out = [];
  for (let m = 8 * 60 + 30; m <= 20 * 60; m += 30) {
    out.push(String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0'));
  }
  return out;
}
const dayKey = (d) =>
  d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
const slotTime = (d) =>
  String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
const isDentist = (r) => {
  r = String(r || '').toLowerCase();
  return r.includes('dentist') || r === 'dentista' || r === 'psicologo';
};

(async () => {
  const G = grade();
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const end = new Date(start.getTime() + 14 * 86400000);
  const clinics = await db.collection('clinics').get();
  for (const c of clinics.docs) {
    const users = await db
      .collection('users')
      .where('allowedClinics', 'array-contains', c.id)
      .get();
    const dentists = users.docs.filter((d) => isDentist(d.data().role)).map((d) => d.id);
    if (!dentists.length) {
      console.log('- ' + c.id + ': sem dentistas, pulei');
      continue;
    }
    const appts = await db
      .collection('appointments')
      .where('clinicId', '==', c.id)
      .where('date', '>=', start)
      .where('date', '<', end)
      .get();
    const busy = {};
    appts.forEach((d) => {
      const m = d.data();
      if (!m.date || !m.dentistId) return;
      if (String(m.status || '').toLowerCase() === 'cancelado') return;
      const dt = m.date.toDate();
      const k = m.dentistId + '.' + dayKey(dt);
      (busy[k] = busy[k] || new Set()).add(slotTime(dt));
    });
    const data = {};
    for (const did of dentists) {
      for (let i = 0; i < 14; i++) {
        const day = new Date(start.getTime() + i * 86400000);
        const k = did + '.' + dayKey(day);
        const b = busy[k] || new Set();
        data[k] = G.filter((s) => !b.has(s));
      }
    }
    await db.collection('portal_slots').doc(c.id).set(data, { merge: true });
    console.log('- ' + c.id + ': ' + Object.keys(data).length + ' dias-dentista OK');
  }
  process.exit(0);
})().catch((e) => {
  console.error('FALHOU:', e.message);
  process.exit(1);
});

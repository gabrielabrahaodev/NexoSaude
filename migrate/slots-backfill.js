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

function grade(cfg) {
  cfg = cfg || {};
  const start = String(cfg.start || '08:30');
  const end = String(cfg.end || '20:00');
  const slot = Number(cfg.slot || 30);
  const toMin = (s) => {
    const p = s.split(':');
    return Number(p[0]) * 60 + Number(p[1]);
  };
  const out = [];
  for (let m = toMin(start); m <= toMin(end); m += slot) {
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
  const clinics = await db.collection('clinics').get();
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const end = new Date(start.getTime() + 14 * 86400000);
  for (const c of clinics.docs) {
    const G = grade(c.data().gradeConfig);
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
      // Expande pela duração (bloco por intervalo ocupa todos os slots).
      const dur = Number(m.durationMinutes || 30);
      const steps = dur <= 0 ? 1 : Math.ceil(dur / 30);
      for (let i = 0; i < steps; i++) {
        const s = new Date(dt.getTime() + i * 1800000);
        const k = m.dentistId + '.' + dayKey(s);
        (busy[k] = busy[k] || new Set()).add(slotTime(s));
      }
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

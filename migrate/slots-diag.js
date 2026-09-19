// Diagnostico: lista clinics + estado do portal_slots de cada uma.
const admin = require('firebase-admin');
const sa = require('C:/Users/gabri/OneDrive/Documents/projetos/flutter/odonto_controle_Alt/migrate/new-key.json');

admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'nexosaude',
});
const db = admin.firestore();

(async () => {
  const clinics = await db.collection('clinics').get();
  console.log('CLINICAS:', clinics.size);
  for (const c of clinics.docs) {
    const s = await db.collection('portal_slots').doc(c.id).get();
    if (!s.exists) {
      console.log('- ' + c.id + ' (' + (c.data().name || '?') + '): SEM ESPELHO');
      continue;
    }
    const keys = Object.keys(s.data() || {});
    console.log('- ' + c.id + ' (' + (c.data().name || '?') + '): ' + keys.length + ' chaves, ex: ' + keys.slice(0, 3).join(', '));
  }
  process.exit(0);
})().catch((e) => {
  console.error('FALHOU:', e.message);
  process.exit(1);
});

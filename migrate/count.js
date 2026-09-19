// Conta docs por colecao raiz (origem x destino) — auditoria da migracao.
const admin = require('firebase-admin');
const oldApp = admin.initializeApp(
  { credential: admin.credential.cert(require(`./${process.argv[2]}`)) },
  'olda'
);
const newApp = admin.initializeApp(
  { credential: admin.credential.cert(require(`./${process.argv[3]}`)) },
  'newa'
);
(async () => {
  for (const [name, app] of [['OLD', oldApp], ['NEW', newApp]]) {
    const db = app.firestore();
    const cols = await db.listCollections();
    console.log(`== ${name} ==`);
    for (const c of cols) {
      const n = (await c.count().get()).data().count;
      console.log(`  ${c.id}: ${n}`);
    }
  }
  process.exit(0);
})().catch((e) => {
  console.error('FALHA:', e.message || e);
  process.exit(1);
});

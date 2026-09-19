/**
 * Migracao completa do Firestore: projeto antigo -> projeto novo.
 *
 * - Copia TODAS as colecoes raiz + TODAS as subcolecoes (recursivo),
 *   mantendo os MESMOS IDs de documento -> vinculos (patientId, planId,
 *   scheduleId, relatedFinancialId etc.) continuam integros, sem remapeamento.
 * - Nao apaga nada na origem. Rode quantas vezes precisar (sobrescreve).
 *
 * Uso:
 *   1. npm install (uma vez)
 *   2. Baixe as chaves service account (IAM > Contas de servico) dos DOIS
 *      projetos em arquivos locais (NUNCA commite nem cole no chat):
 *        old-key.json  (projeto antigo, papel Leitor do Firestore basta p/ origem;
 *                       na pratica use Proprietario/Editor p/ simplificar)
 *        new-key.json  (projeto novo, papel Editor)
 *   3. node migrate.js old-key.json new-key.json
 *   4. Confira os contadores impressos x console do projeto antigo.
 */
const admin = require('firebase-admin');

if (process.argv.length < 4) {
  console.error('Uso: node migrate.js <old-key.json> <new-key.json>');
  process.exit(1);
}

const oldApp = admin.initializeApp(
  { credential: admin.credential.cert(require(`./${process.argv[2]}`)) },
  'old'
);
const newApp = admin.initializeApp(
  { credential: admin.credential.cert(require(`./${process.argv[3]}`)) },
  'new'
);

const src = oldApp.firestore();
const dst = newApp.firestore();
const counts = {};

// BulkWriter trava neste ambiente; set() simples com concorrência
// limitada (Promise.all aberto em 7k docs estoura memória).
async function mapLimit(items, limit, fn) {
  const ret = [];
  const executing = [];
  for (const item of items) {
    const p = fn(item).then((r) => {
      executing.splice(executing.indexOf(p), 1);
      return r;
    });
    ret.push(p);
    executing.push(p);
    if (executing.length >= limit) await Promise.race(executing);
  }
  return Promise.all(ret);
}

async function copyCollection(srcCol, dstCol, path) {
  const snap = await srcCol.get();
  console.log(`... ${path}: ${snap.size} docs`);
  let done = 0;
  await mapLimit(snap.docs, 20, async (doc) => {
    await dstCol.doc(doc.id).set(doc.data());
    counts[path] = (counts[path] || 0) + 1;
    const subs = await doc.ref.listCollections();
    for (const sub of subs) {
      await copyCollection(
        sub,
        dstCol.doc(doc.id).collection(sub.id),
        `${path}/${sub.id}`
      );
    }
    done++;
    if (done % 500 === 0) console.log(`    ${path}: ${done}/${snap.size}`);
  });
  console.log(`OK ${path}: ${counts[path] || 0} docs`);
}

(async () => {
  try {
    const only = (process.env.ONLY || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    const cols = (await src.listCollections()).filter(
      (c) => only.length === 0 || only.includes(c.id)
    );
    console.log(
      `Colecoes raiz: ${cols.map((c) => c.id).join(', ')}`
    );
    for (const col of cols) {
      await copyCollection(col, dst.collection(col.id), col.id);
    }
    console.log('OK. Docs copiados por caminho:');
    console.log(JSON.stringify(counts, null, 2));
    process.exit(0);
  } catch (e) {
    console.error('FALHA:', e.message || e);
    process.exit(1);
  }
})();

// SÓ VALIDA a sintaxe: cria ruleset sem trocar o release (produção intacta).
// Uso: node migrate/rules-validate.js [caminho/rules]
// Rode a partir da raiz do repo. Chave: env GOOGLE_APPLICATION_CREDENTIALS
// ou migrate/*-key.json (ignorado no git; cada operador usa a sua).
const fs = require('fs');
const path = require('path');
const { GoogleAuth } = require('./node_modules/google-auth-library');

const ROOT = process.cwd();
const file = process.argv[2] || path.join(ROOT, 'firestore.rules');
const keyFile = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(ROOT, 'migrate', 'new-key.json');

(async () => {
  const auth = new GoogleAuth({
    keyFile,
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });
  const c = await auth.getClient();
  const t = await c.getAccessToken();
  const H = { Authorization: 'Bearer ' + t.token, 'Content-Type': 'application/json' };
  const content = fs.readFileSync(file, 'utf8');
  const r = await fetch('https://firebaserules.googleapis.com/v1/projects/nexosaude/rulesets', {
    method: 'POST', headers: H,
    body: JSON.stringify({ source: { files: [{ name: 'firestore.rules', content }] } }),
  });
  const j = await r.json();
  if (!r.ok) {
    console.error('SINTAXE INVALIDA:', r.status);
    console.error(JSON.stringify(j).slice(0, 2000));
    process.exit(1);
  }
  console.log('SINTAXE OK — ruleset (sem release):', j.name);
  process.exit(0);
})().catch((e) => { console.error('FALHOU:', e.message); process.exit(1); });

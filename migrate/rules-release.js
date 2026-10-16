// Publica firestore.rules via REST (contorna o 403 do `test` no CLI).
// Uso: node migrate/rules-release.js
// SOMENTE com ordem explícita. Rode a partir da raiz do repo.
// Chave: env GOOGLE_APPLICATION_CREDENTIALS ou migrate/*-key.json
// (ignorado no git; cada operador usa a sua).
const fs = require('fs');
const path = require('path');
const { GoogleAuth } = require('./node_modules/google-auth-library');

const ROOT = process.cwd();
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
  const content = fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8');
  let r = await fetch('https://firebaserules.googleapis.com/v1/projects/nexosaude/rulesets', {
    method: 'POST', headers: H,
    body: JSON.stringify({ source: { files: [{ name: 'firestore.rules', content }] } }),
  });
  let j = await r.json();
  if (!r.ok) { console.error('RULESET FALHOU:', r.status, JSON.stringify(j).slice(0, 400)); process.exit(1); }
  console.log('ruleset:', j.name);
  r = await fetch('https://firebaserules.googleapis.com/v1/projects/nexosaude/releases/cloud.firestore', {
    method: 'PATCH', headers: H,
    body: JSON.stringify({
      release: { name: 'projects/nexosaude/releases/cloud.firestore', rulesetName: j.name },
      updateMask: 'rulesetName',
    }),
  });
  j = await r.json();
  if (!r.ok) { console.error('RELEASE FALHOU:', r.status, JSON.stringify(j).slice(0, 400)); process.exit(1); }
  console.log('RELEASE OK:', j.rulesetName);
  process.exit(0);
})().catch((e) => { console.error('FALHOU:', e.message); process.exit(1); });

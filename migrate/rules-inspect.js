// READ-ONLY: mostra qual ruleset está ao vivo (nome + data) e salva a
// fonte atual em %TEMP%/live-firestore.rules para diff contra o repo.
// Uso: node migrate/rules-inspect.js
// Rode a partir da raiz do repo. Chave: env GOOGLE_APPLICATION_CREDENTIALS
// ou migrate/*-key.json (ignorado no git; cada operador usa a sua).
const fs = require('fs');
const os = require('os');
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
  const H = { Authorization: 'Bearer ' + t.token };
  let r = await fetch('https://firebaserules.googleapis.com/v1/projects/nexosaude/releases/cloud.firestore', { headers: H });
  let j = await r.json();
  if (!r.ok) { console.error('RELEASE FALHOU:', r.status, JSON.stringify(j).slice(0, 300)); process.exit(1); }
  console.log('ruleset ao vivo:', j.rulesetName);
  console.log('updateTime:', j.updateTime);
  r = await fetch('https://firebaserules.googleapis.com/v1/' + j.rulesetName, { headers: H });
  j = await r.json();
  if (!r.ok) { console.error('RULESET FALHOU:', r.status, JSON.stringify(j).slice(0, 300)); process.exit(1); }
  console.log('createTime:', j.createTime);
  for (const f of j.source.files) {
    const out = path.join(os.tmpdir(), 'live-firestore.rules');
    fs.writeFileSync(out, f.content);
    console.log('fonte salva em:', out, '(' + f.content.length + ' chars)');
  }
  process.exit(0);
})().catch((e) => { console.error('FALHOU:', e.message); process.exit(1); });

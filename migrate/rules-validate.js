// SÓ VALIDA a sintaxe: cria ruleset sem trocar o release (produção intacta).
const fs = require('fs');
const { GoogleAuth } = require('C:/Users/gabri/OneDrive/Documents/projetos/flutter/NexoSaude/migrate/node_modules/google-auth-library');

const file = process.argv[2] ||
  'C:/Users/gabri/OneDrive/Documents/projetos/flutter/NexoSaude/firestore.rules';

(async () => {
  const auth = new GoogleAuth({
    keyFile: 'C:/Users/gabri/OneDrive/Documents/projetos/flutter/NexoSaude/migrate/new-key.json',
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

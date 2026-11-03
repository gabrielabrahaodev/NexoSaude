const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const master = fs.readFileSync(path.join(root, 'web', 'master.html'), 'utf8');
const portal = fs.readFileSync(path.join(root, 'web', 'portal.html'), 'utf8');
const assinatura = fs.readFileSync(path.join(root, 'web', 'assinatura.html'), 'utf8');

test('Master não insere WhatsApp de solicitante em JavaScript inline', () => {
  assert.doesNotMatch(master, /onclick\s*=/i);
  assert.match(master, /canSafelyRollbackAuth = !ownerSnap\.exists && ownedClinics\.empty/);
  assert.match(master, /Resultado incerto: conta preservada/);
  assert.match(master, /data-action="go-tab"/);
  assert.match(master, /data-action="create-owner"/);
  assert.match(master, /data-action="whatsapp"/);
  assert.match(master, /button\.addEventListener\('click', \(\) => chamarZap/);
  assert.doesNotMatch(master, /onclick="chamarZap\(/);
  assert.match(master, /replace\(\/[^/]+\/g, '&amp;'\)/);
});

test('Portal usa eventos delegados, sem handlers inline dinâmicos', () => {
  assert.match(portal, /content\.addEventListener\('click'/);
  assert.match(portal, /data-action="confirmar"/);
  assert.match(portal, /data-action="propor-remarcacao"/);
  assert.doesNotMatch(portal, /onclick\s*=/i);
});

test('Portal escapa texto e atributos de dados vindos do Firestore', () => {
  assert.match(portal, /replace\(\/&\/g, '&amp;'\)/);
  assert.match(portal, /replace\(/);
  assert.match(portal, /id="qr-' \+ esc\(x\.id\)/);
  assert.match(portal, /id="tg-' \+ esc\(id\)/);
  assert.match(portal, /id="cf-' \+ esc\(id\)/);
});

test('Página de assinatura não usa IDs dinâmicos em handlers inline', () => {
  assert.match(assinatura, /data-action="toggle-pix"/);
  assert.match(assinatura, /data-action="avisar"/);
  assert.match(assinatura, /content\.addEventListener\('click'/);
  assert.doesNotMatch(assinatura, /onclick="togglePix\(/);
  assert.doesNotMatch(assinatura, /onclick="avisar\(/);
  assert.doesNotMatch(assinatura, /onclick="copiarPix\(/);
  assert.match(assinatura, /replace\(\/&\/g, '&amp;'\)/);
});

test('Pedidos públicos de trial passam pelo Worker com ID token, nunca direto pelo Firestore', () => {
  assert.match(assinatura, /src="\/worker-config\.js"/);
  assert.match(assinatura, /\/v1\/trial\/request/);
  assert.match(assinatura, /currentUser\.getIdToken\(\)/);
  assert.doesNotMatch(assinatura, /collection\('trial_requests'\)\.add\(/);
  assert.doesNotMatch(assinatura, /batch\.set\(requestRef/);
});


const deployScript = fs.readFileSync(path.join(root, 'deploy.bat'), 'utf8');

test('Deploy interrompe quando build ou Hosting falha e preserva páginas públicas', () => {
  assert.match(
    deployScript,
    /call flutter build web[\s\S]*?if errorlevel 1 exit \/b 1/,
  );
  assert.match(
    deployScript,
    /call firebase deploy --only hosting --project=nexosaude\r?\nif errorlevel 1 \([\s\S]*?exit \/b 1[\s\S]*?\)\r?\n\r?\necho --- SUCESSO! SITE ATUALIZADO ---/,
  );
  assert.match(
    deployScript,
    /if exist sistema-interno\\assinatura\.html move sistema-interno\\assinatura\.html \./,
  );
  assert.match(
    deployScript,
    /if exist sistema-interno\\worker-config\.js move sistema-interno\\worker-config\.js \./,
  );
});

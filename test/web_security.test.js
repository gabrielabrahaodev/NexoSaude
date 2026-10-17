const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const master = fs.readFileSync(path.join(root, 'web', 'master.html'), 'utf8');
const portal = fs.readFileSync(path.join(root, 'web', 'portal.html'), 'utf8');

test('Master não insere WhatsApp de solicitante em JavaScript inline', () => {
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

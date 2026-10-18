import test from 'node:test';
import assert from 'node:assert/strict';
import {
  enforceRateLimit,
  enforceTrialRequestIpLimit,
  enforceTrialRequestUserLimit,
  isClinicTrialActive,
  validateTrialRequestPayload,
} from '../workers/private-documents/src/index.js';

test('rate limiter permite requisição quando binding retorna success', async () => {
  let suppliedKey = null;
  await enforceRateLimit({
    UPLOAD_RATE_LIMITER: {
      limit: async ({ key }) => { suppliedKey = key; return { success: true }; },
    },
  }, 'UPLOAD_RATE_LIMITER', 'uid-1:upload', 'blocked');
  assert.equal(suppliedKey, 'uid-1:upload');
});

test('rate limiter responde 429 quando limite é atingido', async () => {
  await assert.rejects(
    enforceRateLimit({
      DELETE_RATE_LIMITER: { limit: async () => ({ success: false }) },
    }, 'DELETE_RATE_LIMITER', 'uid-1:delete', 'limite personalizado'),
    (error) => error.status === 429 && error.message === 'limite personalizado',
  );
});

test('rate limiter falha fechado se o binding estiver ausente', async () => {
  await assert.rejects(
    enforceRateLimit({}, 'UPLOAD_RATE_LIMITER', 'uid-1:upload'),
    (error) => error.status === 503,
  );
});

test('rate limiter falha fechado se o binding Cloudflare lançar erro', async () => {
  await assert.rejects(
    enforceRateLimit({
      CONTENT_RATE_LIMITER: { limit: async () => { throw new Error('unavailable'); } },
    }, 'CONTENT_RATE_LIMITER', 'clinic/patient/file.pdf:123'),
    (error) => error.status === 503,
  );
});


test('trial ausente é aceito somente para os dois IDs de teste explícitos', () => {
  const testClinic = { blockedByAdmin: false };
  assert.equal(isClinicTrialActive('MxftREXD5vjKtE7SyJIH', testClinic, 0), true);
  assert.equal(isClinicTrialActive('VlFVjTlNX8yqijeHyczt', testClinic, 0), true);
  assert.equal(isClinicTrialActive('clinic-nao-regularizada', testClinic, 0), false);
});

test('trial futuro é aceito e trial expirado/bloqueado/inválido é negado', () => {
  const now = Date.parse('2026-10-17T12:00:00.000Z');
  assert.equal(isClinicTrialActive('clinicA', {
    blockedByAdmin: false, trialEndsAt: new Date(now + 1000),
  }, now), true);
  assert.equal(isClinicTrialActive('clinicA', {
    blockedByAdmin: false, trialEndsAt: new Date(now - 1000),
  }, now), false);
  assert.equal(isClinicTrialActive('clinicA', {
    blockedByAdmin: true, trialEndsAt: new Date(now + 1000),
  }, now), false);
  assert.equal(isClinicTrialActive('clinicA', {
    blockedByAdmin: false, trialEndsAt: 'not-a-timestamp',
  }, now), false);
});

test('endpoint de trial valida o payload no servidor', () => {
  const valid = {
    name: 'Maria Souza',
    whatsapp: '+55 (11) 99999-9999',
    clinicName: 'Clinica Central',
    type: 'dental',
  };
  assert.deepEqual(validateTrialRequestPayload(valid, { email: 'maria@example.com' }), {
    name: 'Maria Souza',
    whatsapp: '+55 (11) 99999-9999',
    email: 'maria@example.com',
    clinicName: 'Clinica Central',
    type: 'dental',
  });
  assert.throws(
    () => validateTrialRequestPayload({ ...valid, whatsapp: '11999999999" onclick="x' }, { email: 'maria@example.com' }),
    /WhatsApp válido/,
  );
  assert.throws(
    () => validateTrialRequestPayload({ ...valid, clinicName: '<script>alert(1)</script>' }, { email: 'maria@example.com' }),
    /Nome e clínica/,
  );
  assert.throws(
    () => validateTrialRequestPayload({ ...valid, type: 'multi' }, { email: 'maria@example.com' }),
    /Tipo de clínica inválido/,
  );
  assert.throws(
    () => validateTrialRequestPayload(valid, { email: 'not-an-email' }),
    /e-mail válido/,
  );
});

test('rate limits do pedido de trial usam bindings separados por IP e UID', async () => {
  const observed = [];
  const env = {
    TRIAL_REQUEST_IP_RATE_LIMITER: { limit: async ({ key }) => { observed.push(['ip', key]); return { success: true }; } },
    TRIAL_REQUEST_USER_RATE_LIMITER: { limit: async ({ key }) => { observed.push(['uid', key]); return { success: true }; } },
  };
  await enforceTrialRequestIpLimit(env, '203.0.113.10');
  await enforceTrialRequestUserLimit(env, 'owner-1');
  assert.deepEqual(observed, [
    ['ip', '203.0.113.10'],
    ['uid', 'owner-1:trial-request'],
  ]);
});

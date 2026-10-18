import test from 'node:test';
import assert from 'node:assert/strict';
import { enforceRateLimit } from '../workers/private-documents/src/index.js';

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

import test from 'node:test';
import assert from 'node:assert/strict';
import { handleRequest } from './server.mjs';

test('rejects requests without configured bearer token', async () => {
  const response = await handleRequest(new Request('http://local/price-check/identify', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}',
  }), { PRICE_CHECK_BEARER_TOKEN: 'secret', ANTHROPIC_API_KEY: 'unused' });
  assert.equal(response.status, 401);
});

test('rejects unknown stages', async () => {
  const response = await handleRequest(new Request('http://local/price-check/unknown', { method: 'POST' }));
  assert.equal(response.status, 404);
});

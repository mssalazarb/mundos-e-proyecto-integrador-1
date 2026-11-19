'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { createApp } = require('../src/app');

const app = createApp({ rateLimitMax: 1000 });

test('GET /health responde ok', async () => {
  const res = await request(app).get('/health');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { status: 'ok' });
});

test('POST /api/v1/passwords genera una contraseña', async () => {
  const res = await request(app).post('/api/v1/passwords').send({ length: 20, symbols: false });
  assert.equal(res.status, 200);
  assert.equal(res.body.passwords[0].length, 20);
  assert.equal(res.headers['cache-control'], 'no-store');
});

test('POST con cuerpo vacío usa los valores por defecto', async () => {
  const res = await request(app).post('/api/v1/passwords').send({});
  assert.equal(res.status, 200);
  assert.equal(res.body.passwords[0].length, 16);
});

test('POST con parámetros inválidos devuelve 400', async () => {
  const res = await request(app).post('/api/v1/passwords').send({ length: 3 });
  assert.equal(res.status, 400);
  assert.ok(res.body.error);
});

test('POST con JSON malformado devuelve 400 sin stack trace', async () => {
  const res = await request(app)
    .post('/api/v1/passwords')
    .set('Content-Type', 'application/json')
    .send('{no-es-json');
  assert.equal(res.status, 400);
  assert.ok(!JSON.stringify(res.body).includes('at '));
});

test('GET /metrics expone métricas de Prometheus', async () => {
  await request(app).post('/api/v1/passwords').send({ count: 3 });
  const res = await request(app).get('/metrics');
  assert.equal(res.status, 200);
  assert.match(res.text, /passfly_passwords_generated_total/);
  assert.match(res.text, /passfly_http_request_duration_seconds/);
});

test('las métricas no contienen contraseñas', async () => {
  const gen = await request(app).post('/api/v1/passwords').send({});
  const res = await request(app).get('/metrics');
  assert.ok(!res.text.includes(gen.body.passwords[0]));
});

test('incluye cabeceras de seguridad y oculta x-powered-by', async () => {
  const res = await request(app).get('/health');
  assert.ok(res.headers['content-security-policy']);
  assert.equal(res.headers['x-powered-by'], undefined);
});

test('sirve el frontend en /', async () => {
  const res = await request(app).get('/');
  assert.equal(res.status, 200);
  assert.match(res.text, /PassFly/);
});

test('aplica rate limiting', async () => {
  const limited = createApp({ rateLimitMax: 2 });
  await request(limited).post('/api/v1/passwords').send({});
  await request(limited).post('/api/v1/passwords').send({});
  const res = await request(limited).post('/api/v1/passwords').send({});
  assert.equal(res.status, 429);
});

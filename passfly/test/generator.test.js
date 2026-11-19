'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { generate, ValidationError, SETS } = require('../src/generator');

test('usa valores por defecto (16 caracteres)', () => {
  const { passwords } = generate();
  assert.equal(passwords.length, 1);
  assert.equal(passwords[0].length, 16);
});

test('respeta la longitud pedida', () => {
  for (const length of [8, 20, 64, 128]) {
    assert.equal(generate({ length }).passwords[0].length, length);
  }
});

test('incluye al menos un carácter de cada tipo seleccionado', () => {
  for (let i = 0; i < 200; i++) {
    const [p] = generate({ length: 8 }).passwords;
    assert.match(p, /[a-z]/);
    assert.match(p, /[A-Z]/);
    assert.match(p, /[0-9]/);
    assert.match(p, /[^a-zA-Z0-9]/);
  }
});

test('solo usa los tipos activados', () => {
  const [p] = generate({ length: 64, lowercase: false, uppercase: false, symbols: false }).passwords;
  assert.match(p, /^[0-9]+$/);
  const [q] = generate({ length: 64, numbers: false, symbols: false, uppercase: false }).passwords;
  assert.match(q, /^[a-z]+$/);
});

test('excluye caracteres ambiguos', () => {
  for (let i = 0; i < 100; i++) {
    const [p] = generate({ length: 64, excludeAmbiguous: true }).passwords;
    assert.doesNotMatch(p, /[O0Il1|]/);
  }
});

test('símbolos pertenecen al conjunto definido', () => {
  const [p] = generate({ length: 128, lowercase: false, uppercase: false, numbers: false }).passwords;
  for (const ch of p) assert.ok(SETS.symbols.includes(ch));
});

test('genera varias contraseñas distintas', () => {
  const { passwords } = generate({ count: 10, length: 24 });
  assert.equal(new Set(passwords).size, 10);
});

test('calcula entropía y fortaleza', () => {
  assert.equal(generate({ length: 8, uppercase: false, numbers: false, symbols: false }).strength, 'débil');
  assert.equal(generate({ length: 32 }).strength, 'muy fuerte');
});

test('rechaza parámetros inválidos', () => {
  const bad = [
    { length: 7 }, { length: 129 }, { length: 12.5 }, { length: '16' },
    { count: 0 }, { count: 11 }, { lowercase: 'yes' },
    { lowercase: false, uppercase: false, numbers: false, symbols: false },
  ];
  for (const input of bad) {
    assert.throws(() => generate(input), ValidationError, JSON.stringify(input));
  }
});

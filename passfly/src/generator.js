'use strict';

const { randomInt } = require('node:crypto');

const SETS = Object.freeze({
  lowercase: 'abcdefghijklmnopqrstuvwxyz',
  uppercase: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
  numbers: '0123456789',
  symbols: '!@#$%^&*()-_=+[]{};:,.?/',
});

const AMBIGUOUS = /[O0Il1|]/g;

const LIMITS = Object.freeze({
  minLength: 8,
  maxLength: 128,
  defaultLength: 16,
  maxCount: 10,
});

class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
  }
}

function pick(chars) {
  return chars[randomInt(chars.length)];
}

// Fisher-Yates con aleatoriedad criptográfica
function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function normalizeOptions(input = {}) {
  const opts = {
    length: input.length ?? LIMITS.defaultLength,
    lowercase: input.lowercase ?? true,
    uppercase: input.uppercase ?? true,
    numbers: input.numbers ?? true,
    symbols: input.symbols ?? true,
    excludeAmbiguous: input.excludeAmbiguous ?? false,
    count: input.count ?? 1,
  };

  if (!Number.isInteger(opts.length) || opts.length < LIMITS.minLength || opts.length > LIMITS.maxLength) {
    throw new ValidationError(`length debe ser un entero entre ${LIMITS.minLength} y ${LIMITS.maxLength}`);
  }
  if (!Number.isInteger(opts.count) || opts.count < 1 || opts.count > LIMITS.maxCount) {
    throw new ValidationError(`count debe ser un entero entre 1 y ${LIMITS.maxCount}`);
  }
  for (const key of ['lowercase', 'uppercase', 'numbers', 'symbols', 'excludeAmbiguous']) {
    if (typeof opts[key] !== 'boolean') {
      throw new ValidationError(`${key} debe ser booleano`);
    }
  }
  if (!opts.lowercase && !opts.uppercase && !opts.numbers && !opts.symbols) {
    throw new ValidationError('Debe activarse al menos un tipo de carácter');
  }
  return opts;
}

function activePools(opts) {
  return ['lowercase', 'uppercase', 'numbers', 'symbols']
    .filter((k) => opts[k])
    .map((k) => (opts.excludeAmbiguous ? SETS[k].replace(AMBIGUOUS, '') : SETS[k]));
}

function generateOne(pools, length) {
  const all = pools.join('');
  // Garantiza al menos un carácter de cada tipo seleccionado
  const chars = pools.map(pick);
  while (chars.length < length) chars.push(pick(all));
  return shuffle(chars).join('');
}

function entropyBits(opts) {
  const size = activePools(opts).reduce((n, p) => n + p.length, 0);
  return Math.round(opts.length * Math.log2(size));
}

function strengthLabel(bits) {
  if (bits < 50) return 'débil';
  if (bits < 80) return 'media';
  if (bits < 110) return 'fuerte';
  return 'muy fuerte';
}

function generate(input) {
  const opts = normalizeOptions(input);
  const pools = activePools(opts);
  const passwords = Array.from({ length: opts.count }, () => generateOne(pools, opts.length));
  const bits = entropyBits(opts);
  return { passwords, entropyBits: bits, strength: strengthLabel(bits) };
}

module.exports = { generate, ValidationError, LIMITS, SETS };

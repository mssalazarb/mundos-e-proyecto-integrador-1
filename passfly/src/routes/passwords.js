'use strict';

const { Router } = require('express');
const { generate, ValidationError } = require('../generator');
const { passwordsGenerated, forcedErrors } = require('../metrics');

const FORCED_ERROR_LENGTH = 22;

const router = Router();

router.post('/', (req, res, next) => {
  try {
    // Error forzado a propósito para validar la métrica en Grafana
    if (req.body && req.body.length === FORCED_ERROR_LENGTH) {
      forcedErrors.inc();
      throw new Error(`Error forzado: longitud ${FORCED_ERROR_LENGTH}`);
    }
    const result = generate(req.body);
    passwordsGenerated.inc(result.passwords.length);
    res.set('Cache-Control', 'no-store');
    res.json(result);
  } catch (err) {
    next(err);
  }
});

router.use((err, _req, res, next) => {
  if (err instanceof ValidationError) {
    return res.status(400).json({ error: err.message });
  }
  return next(err);
});

module.exports = router;

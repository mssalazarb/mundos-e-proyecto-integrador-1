'use strict';

const { Router } = require('express');
const { generate, ValidationError } = require('../generator');
const { passwordsGenerated } = require('../metrics');

const router = Router();

router.post('/', (req, res, next) => {
  try {
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

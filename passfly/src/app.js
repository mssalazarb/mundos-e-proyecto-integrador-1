'use strict';

const path = require('node:path');
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const passwordsRouter = require('./routes/passwords');
const { register, httpMetrics } = require('./metrics');

function createApp({ rateLimitMax = 60 } = {}) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);

  app.use(helmet());
  app.use(httpMetrics);
  app.use(express.json({ limit: '1kb' }));

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  const limiter = rateLimit({
    windowMs: 60 * 1000,
    limit: rateLimitMax,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Demasiadas peticiones, intenta de nuevo en un minuto' },
  });
  app.use('/api/v1/passwords', limiter, passwordsRouter);

  app.use(express.static(path.join(__dirname, '..', 'public')));

  // JSON inválido u otros errores: nunca exponer stack traces
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    const status = err.status && err.status < 500 ? err.status : 500;
    res.status(status).json({ error: status === 500 ? 'Error interno' : 'Petición inválida' });
  });

  return app;
}

module.exports = { createApp };

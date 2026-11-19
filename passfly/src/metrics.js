'use strict';

const client = require('prom-client');

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const passwordsGenerated = new client.Counter({
  name: 'passfly_passwords_generated_total',
  help: 'Total de contraseñas generadas (nunca se almacena su contenido)',
  registers: [register],
});

const httpDuration = new client.Histogram({
  name: 'passfly_http_request_duration_seconds',
  help: 'Duración de las peticiones HTTP',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1],
  registers: [register],
});

function httpMetrics(req, res, next) {
  const end = httpDuration.startTimer();
  res.on('finish', () => {
    const route = req.route ? req.baseUrl + req.route.path : 'other';
    end({ method: req.method, route, status: res.statusCode });
  });
  next();
}

module.exports = { register, passwordsGenerated, httpMetrics };

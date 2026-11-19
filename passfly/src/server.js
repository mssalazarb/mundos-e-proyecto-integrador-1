'use strict';

const { createApp } = require('./app');

const port = Number(process.env.PORT) || 3000;
const server = createApp().listen(port, '0.0.0.0', () => {
  console.log(`PassFly escuchando en el puerto ${port}`);
});

function shutdown() {
  server.close(() => process.exit(0));
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

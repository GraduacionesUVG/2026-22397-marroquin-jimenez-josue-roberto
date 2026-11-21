'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const tls = require('node:tls');

const { buildSslConfig } = require('../src/config/db');

const FIXTURES = path.join(__dirname, 'fixtures', 'tls');
const CA_FILE = path.join(FIXTURES, 'ca.pem');
const OTHER_CA_FILE = path.join(FIXTURES, 'other-ca.pem');
const RDS_BUNDLE = path.join(__dirname, '..', 'certs', 'rds-global-bundle.pem');

// Servidor TLS con un certificado emitido para "localhost". node-postgres
// llama a tls.connect con estas mismas opciones y servername = host, asi que
// la prueba ejercita la validacion real y no solo la forma del objeto.
async function withTlsServer(fn) {
  const server = tls.createServer({
    key: fs.readFileSync(path.join(FIXTURES, 'server-key.pem')),
    cert: fs.readFileSync(path.join(FIXTURES, 'server.pem')),
  }, (socket) => socket.end());
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await fn(server.address().port);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

function handshake(port, servername, ssl) {
  return new Promise((resolve, reject) => {
    const socket = tls.connect({ ...ssl, host: '127.0.0.1', port, servername }, () => {
      socket.end();
      resolve('ok');
    });
    socket.on('error', reject);
  });
}

test('verify-full exige el paquete de CA', () => {
  assert.throws(() => buildSslConfig({ POSTGRES_SSL_MODE: 'verify-full' }), /POSTGRES_SSL_CA_FILE/);
});

test('verify-full valida la cadena y el nombre del servidor', () => {
  const ssl = buildSslConfig({ POSTGRES_SSL_MODE: 'verify-full', POSTGRES_SSL_CA_FILE: CA_FILE });
  assert.equal(ssl.rejectUnauthorized, true);
  assert.equal(ssl.checkServerIdentity, undefined);
  assert.match(ssl.ca, /BEGIN CERTIFICATE/);
});

test('PGSSLMODE sigue funcionando cuando POSTGRES_SSL_MODE no esta definida', () => {
  const ssl = buildSslConfig({ PGSSLMODE: 'verify-full', POSTGRES_SSL_CA_FILE: CA_FILE });
  assert.equal(ssl.rejectUnauthorized, true);
});

test('no-verify y require cifran sin validar; disable no cifra', () => {
  assert.deepEqual(buildSslConfig({ PGSSLMODE: 'no-verify' }), { rejectUnauthorized: false });
  assert.deepEqual(buildSslConfig({ POSTGRES_SSL_MODE: 'require' }), { rejectUnauthorized: false });
  assert.equal(buildSslConfig({}), false);
  assert.throws(() => buildSslConfig({ POSTGRES_SSL_MODE: 'verify' }), /not valid/);
});

test('el paquete de RDS incluido en la imagen se puede cargar', () => {
  const ssl = buildSslConfig({ POSTGRES_SSL_MODE: 'verify-full', POSTGRES_SSL_CA_FILE: RDS_BUNDLE });
  assert.ok((ssl.ca.match(/BEGIN CERTIFICATE/g) ?? []).length > 10);
});

test('verify-full acepta la CA y el nombre correctos', async () => {
  const ssl = buildSslConfig({ POSTGRES_SSL_MODE: 'verify-full', POSTGRES_SSL_CA_FILE: CA_FILE });
  await withTlsServer(async (port) => {
    assert.equal(await handshake(port, 'localhost', ssl), 'ok');
  });
});

test('verify-full rechaza un nombre de servidor distinto', async () => {
  const ssl = buildSslConfig({ POSTGRES_SSL_MODE: 'verify-full', POSTGRES_SSL_CA_FILE: CA_FILE });
  await withTlsServer(async (port) => {
    await assert.rejects(handshake(port, 'otro-host.internal', ssl), { code: 'ERR_TLS_CERT_ALTNAME_INVALID' });
  });
});

test('verify-full rechaza un servidor firmado por otra CA', async () => {
  const ssl = buildSslConfig({ POSTGRES_SSL_MODE: 'verify-full', POSTGRES_SSL_CA_FILE: OTHER_CA_FILE });
  await withTlsServer(async (port) => {
    await assert.rejects(handshake(port, 'localhost', ssl), (err) => /self.signed|unable to verify|UNABLE_TO_VERIFY|SELF_SIGNED/i.test(`${err.code} ${err.message}`));
  });
});

test('verify-ca valida la cadena pero no el nombre', async () => {
  const ssl = buildSslConfig({ POSTGRES_SSL_MODE: 'verify-ca', POSTGRES_SSL_CA_FILE: CA_FILE });
  await withTlsServer(async (port) => {
    assert.equal(await handshake(port, 'otro-host.internal', ssl), 'ok');
  });
});

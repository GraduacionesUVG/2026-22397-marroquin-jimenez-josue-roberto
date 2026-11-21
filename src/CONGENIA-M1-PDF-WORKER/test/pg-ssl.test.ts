import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import tls from 'node:tls';
import type { AddressInfo } from 'node:net';

import { buildSslConfig } from '../src/lib/pg-ssl';

const FIXTURES = path.join(__dirname, 'fixtures', 'tls');
const CA_FILE = path.join(FIXTURES, 'ca.pem');
const OTHER_CA_FILE = path.join(FIXTURES, 'other-ca.pem');
const RDS_BUNDLE = path.join(__dirname, '..', 'certs', 'rds-global-bundle.pem');

// Servidor TLS con certificado para "localhost": node-postgres usa tls.connect
// con estas opciones y servername = host.
async function withTlsServer<T>(fn: (port: number) => Promise<T>): Promise<T> {
  const server = tls.createServer({
    key: readFileSync(path.join(FIXTURES, 'server-key.pem')),
    cert: readFileSync(path.join(FIXTURES, 'server.pem')),
  }, (socket) => socket.end());
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await fn((server.address() as AddressInfo).port);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
}

function handshake(port: number, servername: string, ssl: tls.ConnectionOptions): Promise<string> {
  return new Promise((resolve, reject) => {
    const socket = tls.connect({ ...ssl, host: '127.0.0.1', port, servername }, () => {
      socket.end();
      resolve('ok');
    });
    socket.on('error', reject);
  });
}

function verifyFull(caFile: string): tls.ConnectionOptions {
  const ssl = buildSslConfig({ POSTGRES_SSL_MODE: 'verify-full', POSTGRES_SSL_CA_FILE: caFile });
  assert.ok(ssl);
  return ssl;
}

test('verify-full exige el paquete de CA', () => {
  assert.throws(() => buildSslConfig({ POSTGRES_SSL_MODE: 'verify-full' }), /POSTGRES_SSL_CA_FILE/);
});

test('modos sin validacion y disable conservan el comportamiento anterior', () => {
  assert.deepEqual(buildSslConfig({ PGSSLMODE: 'no-verify' }), { rejectUnauthorized: false });
  assert.equal(buildSslConfig({}), false);
  assert.throws(() => buildSslConfig({ PGSSLMODE: 'verify' }), /not valid/);
});

test('el paquete de RDS incluido en la imagen se puede cargar', () => {
  const ssl = verifyFull(RDS_BUNDLE);
  assert.ok(String(ssl.ca).split('BEGIN CERTIFICATE').length > 10);
});

test('verify-full acepta la CA y el nombre correctos', async () => {
  await withTlsServer(async (port) => assert.equal(await handshake(port, 'localhost', verifyFull(CA_FILE)), 'ok'));
});

test('verify-full rechaza un nombre de servidor distinto', async () => {
  await withTlsServer(async (port) => {
    await assert.rejects(handshake(port, 'otro-host.internal', verifyFull(CA_FILE)), { code: 'ERR_TLS_CERT_ALTNAME_INVALID' });
  });
});

test('verify-full rechaza un servidor firmado por otra CA', async () => {
  await withTlsServer(async (port) => {
    await assert.rejects(handshake(port, 'localhost', verifyFull(OTHER_CA_FILE)));
  });
});

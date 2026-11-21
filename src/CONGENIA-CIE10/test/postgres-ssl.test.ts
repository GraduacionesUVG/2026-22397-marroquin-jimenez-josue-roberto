import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import tls from "node:tls";
import type { AddressInfo } from "node:net";
import { fileURLToPath } from "node:url";

import { sslConfig } from "../src/db/postgres.js";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES = path.join(HERE, "fixtures", "tls");
const CA_FILE = path.join(FIXTURES, "ca.pem");
const OTHER_CA_FILE = path.join(FIXTURES, "other-ca.pem");
const RDS_BUNDLE = path.join(HERE, "..", "certs", "rds-global-bundle.pem");

async function withTlsServer<T>(fn: (port: number) => Promise<T>): Promise<T> {
  const server = tls.createServer({
    key: readFileSync(path.join(FIXTURES, "server-key.pem")),
    cert: readFileSync(path.join(FIXTURES, "server.pem")),
  }, (socket) => socket.end());
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  try {
    return await fn((server.address() as AddressInfo).port);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
}

function handshake(port: number, servername: string, ssl: tls.ConnectionOptions): Promise<string> {
  return new Promise((resolve, reject) => {
    const socket = tls.connect({ ...ssl, host: "127.0.0.1", port, servername }, () => {
      socket.end();
      resolve("ok");
    });
    socket.on("error", reject);
  });
}

function verifyFull(caFile: string): tls.ConnectionOptions {
  const ssl = sslConfig("verify-full", caFile);
  assert.ok(ssl);
  return ssl;
}

test("verify-full exige el paquete de CA", () => {
  assert.throws(() => sslConfig("verify-full", undefined), /POSTGRES_SSL_CA_FILE/);
});

test("el paquete de RDS incluido en la imagen se puede cargar", () => {
  assert.ok(String(verifyFull(RDS_BUNDLE).ca).split("BEGIN CERTIFICATE").length > 10);
});

test("verify-full acepta la CA y el nombre correctos", async () => {
  await withTlsServer(async (port) => assert.equal(await handshake(port, "localhost", verifyFull(CA_FILE)), "ok"));
});

test("verify-full rechaza un nombre de servidor distinto", async () => {
  await withTlsServer(async (port) => {
    await assert.rejects(handshake(port, "otro-host.internal", verifyFull(CA_FILE)), { code: "ERR_TLS_CERT_ALTNAME_INVALID" });
  });
});

test("verify-full rechaza un servidor firmado por otra CA", async () => {
  await withTlsServer(async (port) => {
    await assert.rejects(handshake(port, "localhost", verifyFull(OTHER_CA_FILE)));
  });
});

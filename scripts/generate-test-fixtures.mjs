// Synthetic fixtures only. Node/OpenSSL is independent of Swift CryptoKit/CommonCrypto.
// Fixed salt/nonce are solely for reproducible tests, never for real encryption.
import { createCipheriv, createHmac, pbkdf2Sync } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const directory = fileURLToPath(new URL('../Tests/OTPBarCoreTests/Fixtures/', import.meta.url));
mkdirSync(directory, { recursive: true });
const write = (name, value) => writeFileSync(`${directory}/${name}.json`, `${JSON.stringify(value, null, 2)}\n`);
const base32 = (bytes) => {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = [...bytes].map(value => value.toString(2).padStart(8, '0')).join('');
  bits = bits.padEnd(Math.ceil(bits.length / 5) * 5, '0');
  return bits.match(/.{5}/g).map(chunk => alphabet[parseInt(chunk, 2)]).join('');
};
const secret = Buffer.from('12345678901234567890'); // Public RFC 4226 test key.
const services = [
  { name: 'Example second', secret: base32(Buffer.from('12345678901234567890123456789012')),
    otp: { account: 'second@example.invalid', tokenType: 'TOTP', algorithm: 'SHA256', digits: 8, period: 60 },
    order: { position: 1 }, updatedAt: 0, unknownFutureField: { keep: true } },
  { name: 'Example first', secret: base32(secret),
    otp: { account: 'first@example.invalid', tokenType: 'TOTP', algorithm: 'SHA1', digits: 6, period: 30 },
    order: { position: 0 }, updatedAt: 0 }
];
const envelope = { schemaVersion: 4, appOrigin: 'ios', appVersionName: 'test-only',
  services, groups: [], unknownRootField: ['never rewrite this source'] };
write('plaintext-v4', envelope);
write('plaintext-v3', { ...envelope, schemaVersion: 3, appOrigin: 'android' });
const reference = 'tRViSsLKzd86Hprh4ceC2OP7xazn4rrt4xhfEUbOjxLX8Rc3mkISXE0lWbmnWfggogbBJhtYgpK6fMl1D6mtsy92R3HkdGfwuXbzLebqVFJsR7IZ2w58t938iymwG4824igYy1wi6n2WDpO1Q1P69zwJGs2F5a1qP4MyIiDSD7NCV2OvidXQCBnDlGfmz0f1BQySRkkt4ryiJeCjD2o4QsveJ9uDBUn8ELyOrESv5R5DMDkD4iAF8TXU7KyoJujd';
const encrypt = (text, password, nonceByte) => {
  const salt = Buffer.from(Array.from({ length: 32 }, (_, i) => i));
  const nonce = Buffer.alloc(12, nonceByte);
  const key = pbkdf2Sync(Buffer.from(password, 'utf8'), salt, 10000, 32, 'sha256');
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  const payload = Buffer.concat([cipher.update(text, 'utf8'), cipher.final(), cipher.getAuthTag()]);
  return [payload, salt, nonce].map(value => value.toString('base64')).join(':');
};
for (const [name, password, origin] of [
  ['ascii', 'otpbar-test-only', 'ios'], ['utf8', '测试密码🔑', 'android'], ['empty', '', 'android']
]) {
  write(`encrypted-${name}-v4`, { ...envelope, appOrigin: origin, services: [],
    servicesEncrypted: encrypt(JSON.stringify(services), password, 1), reference: encrypt(reference, password, 2) });
}
write('encrypted-bad-reference-v4', { ...envelope, services: [],
  servicesEncrypted: encrypt(JSON.stringify(services), 'otpbar-test-only', 1),
  reference: encrypt('incorrect public marker', 'otpbar-test-only', 2) });

// Independent reference values for all supported parameters, including subsecond rollover.
const matrix = [];
for (const algorithm of ['SHA1', 'SHA256', 'SHA512']) {
  for (const digits of [5, 6, 7, 8]) {
    for (const period of [10, 30, 60, 90]) {
      for (const timestamp of [0, period - 0.001, period, period + 0.001, 1234567890, 20000000000]) {
        const message = Buffer.alloc(8);
        message.writeBigUInt64BE(BigInt(Math.floor(timestamp / period)));
        const digest = createHmac(algorithm.toLowerCase(), secret).update(message).digest();
        const offset = digest[digest.length - 1] & 15;
        const truncated = digest.readUInt32BE(offset) & 0x7fffffff;
        matrix.push({ algorithm, digits, period, timestamp,
          code: String(truncated % (10 ** digits)).padStart(digits, '0') });
      }
    }
  }
}
write('totp-matrix', matrix);
write('rfc-seeds', [20, 32, 64].map(length => base32(Buffer.from('1234567890'.repeat(7).slice(0, length)))));

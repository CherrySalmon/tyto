import { execSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Playwright global setup: mint a login credential for every seeded
// `@e2e.test` account in a single Ruby boot and cache them to
// e2e/.auth/credentials.json. The loginAs() fixture reads this file and sets
// the session cookies — no Google OAuth, no per-test rake invocation.
//
// Requires the test DB to be seeded already (rake spec:e2e handles that). This
// does no HTTP, so it is independent of the webServer start order.

const here = dirname(fileURLToPath(import.meta.url));
export const CREDENTIALS_PATH = resolve(here, '.auth/credentials.json');

export default function globalSetup() {
  const raw = execSync('RACK_ENV=test bundle exec rake generate:e2e_credentials', {
    cwd: resolve(here, '..'),
    encoding: 'utf8',
    maxBuffer: 10 * 1024 * 1024,
  });

  // The rake task prints one JSON object on its own line; ignore any boot noise.
  const jsonLine = raw
    .trim()
    .split('\n')
    .reverse()
    .find((line) => line.trim().startsWith('{'));

  if (!jsonLine) {
    throw new Error(`Could not find credential JSON in rake output:\n${raw}`);
  }

  const credentials = JSON.parse(jsonLine);
  const roles = Object.keys(credentials);
  if (roles.length === 0) {
    throw new Error('No @e2e.test accounts found — is the test DB seeded?');
  }

  mkdirSync(dirname(CREDENTIALS_PATH), { recursive: true });
  writeFileSync(CREDENTIALS_PATH, JSON.stringify(credentials, null, 2));
  console.log(`[e2e] minted credentials for roles: ${roles.join(', ')}`);
}

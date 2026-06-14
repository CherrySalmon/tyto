import { execSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Seed-reference data for the specs, sourced from the SAME Ruby fixtures the DB
// seed uses (Tyto::E2EFixtures). We shell out to `rake generate:e2e_seed_data`
// — a pure-data task, no app boot, no DB — and parse its one JSON line, so the
// specs and the seeded course/location/event can never drift.
//
// This runs eagerly at import (not lazily like credentials.json): some values
// are used at Playwright *collection* time — e.g. `test.use({ geolocation })`
// and the live-session name — which is before global setup runs. Node caches
// the module, so the rake task is invoked once per `playwright test` process.

const here = dirname(fileURLToPath(import.meta.url));

function loadSeedData() {
  const raw = execSync('bundle exec rake generate:e2e_seed_data', {
    cwd: resolve(here, '..'),
    encoding: 'utf8',
    maxBuffer: 10 * 1024 * 1024,
  });

  // The task prints one JSON object on its own line; ignore any boot noise.
  const jsonLine = raw
    .trim()
    .split('\n')
    .reverse()
    .find((line) => line.trim().startsWith('{'));

  if (!jsonLine) {
    throw new Error(`Could not find seed-data JSON in rake output:\n${raw}`);
  }
  return JSON.parse(jsonLine);
}

// Shape (see Tyto::E2EFixtures.as_json):
//   SEED.course.name        -> 'E2E Course'
//   SEED.event.name         -> 'E2E Live Session'
//   SEED.mainHall           -> { name, latitude, longitude }  (the geo-fence)
//   SEED.spareRoom.name     -> 'E2E Spare Room'
//   SEED.accounts.staff.email, ...
export const SEED = loadSeedData();

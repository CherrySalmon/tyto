import { describe, it, expect, afterEach, vi } from 'vitest';

async function freshLoader() {
  vi.resetModules();
  return (await import('./googleMaps.js')).loadGoogleMaps;
}

function mapsScripts() {
  return document.head.querySelectorAll('script[src*="maps.googleapis.com"]');
}

afterEach(() => {
  mapsScripts().forEach((script) => script.remove());
  delete globalThis.google;
});

describe('loadGoogleMaps', () => {
  it('does not inject a script when the API is already present', async () => {
    globalThis.google = { maps: {} };
    const loadGoogleMaps = await freshLoader();
    await loadGoogleMaps();
    expect(mapsScripts()).toHaveLength(0);
  });

  it('injects the script once for concurrent callers and resolves on load', async () => {
    const loadGoogleMaps = await freshLoader();
    const first = loadGoogleMaps();
    const second = loadGoogleMaps();
    expect(second).toBe(first);
    expect(mapsScripts()).toHaveLength(1);

    globalThis.google = { maps: {} };
    mapsScripts()[0].onload();
    await expect(first).resolves.toBeUndefined();
  });

  it('lets a later call retry after the script fails to load', async () => {
    const loadGoogleMaps = await freshLoader();
    const failed = loadGoogleMaps();
    mapsScripts()[0].onerror();
    await expect(failed).rejects.toThrow('Google Maps');

    loadGoogleMaps();
    expect(mapsScripts()).toHaveLength(2);
  });
});

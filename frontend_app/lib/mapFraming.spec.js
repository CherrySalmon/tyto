import { describe, it, expect } from 'vitest';
import { framingFor, DEFAULT_CENTER, SINGLE_LOCATION_ZOOM } from './mapFraming.js';

const HALL = { id: 1, name: 'Hall', latitude: 24.79, longitude: 120.99 };
const LAB = { id: 2, name: 'Lab', latitude: 24.80, longitude: 121.00 };
const HERE = { lat: 25, lng: 121.5 };

describe('framingFor', () => {
  it('fits bounds around two or more locations', () => {
    expect(framingFor([HALL, LAB], HERE)).toEqual({
      kind: 'bounds',
      points: [{ lat: 24.79, lng: 120.99 }, { lat: 24.80, lng: 121.00 }],
    });
  });

  it('centers on a single location at street zoom', () => {
    expect(framingFor([HALL], HERE)).toEqual({
      kind: 'center',
      center: { lat: 24.79, lng: 120.99 },
      zoom: SINGLE_LOCATION_ZOOM,
    });
  });

  it('centers on the fallback position when there are no locations', () => {
    expect(framingFor([], HERE)).toEqual({ kind: 'center', center: HERE, zoom: SINGLE_LOCATION_ZOOM });
  });

  it('uses the default center with no locations and no fallback', () => {
    expect(framingFor([], null)).toEqual({ kind: 'center', center: DEFAULT_CENTER, zoom: SINGLE_LOCATION_ZOOM });
    expect(framingFor(undefined)).toEqual({ kind: 'center', center: DEFAULT_CENTER, zoom: SINGLE_LOCATION_ZOOM });
  });

  it('skips locations without coordinates', () => {
    const noCoords = { id: 3, name: 'Somewhere', latitude: null, longitude: null };
    expect(framingFor([noCoords, HALL], HERE)).toEqual({
      kind: 'center',
      center: { lat: 24.79, lng: 120.99 },
      zoom: SINGLE_LOCATION_ZOOM,
    });
  });
});

// Decides how the Locations map frames a course's locations: fit bounds
// around several, center on one (fitting a single point zooms in too far),
// or fall back to a position (the user's, else a default) when there are none.

export const DEFAULT_CENTER = { lat: 24.793701145, lng: 120.9957896 };
export const SINGLE_LOCATION_ZOOM = 16;

export function hasCoordinates(location) {
  return Number.isFinite(location.latitude) && Number.isFinite(location.longitude);
}

export function framingFor(locations = [], fallback = null) {
  const points = locations
    .filter(hasCoordinates)
    .map((location) => ({ lat: location.latitude, lng: location.longitude }));

  if (points.length > 1) return { kind: 'bounds', points };

  const center = points[0] ?? fallback ?? DEFAULT_CENTER;
  return { kind: 'center', center, zoom: SINGLE_LOCATION_ZOOM };
}

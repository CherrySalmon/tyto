// Loads the Google Maps JavaScript API once per page. Concurrent callers share
// one <script>; a failed load is forgotten so a later call can retry.

let loading = null;

export function loadGoogleMaps() {
  if (globalThis.google?.maps) return Promise.resolve();
  if (loading) return loading;

  loading = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${process.env.VUE_APP_GOOGLE_MAP_KEY}`;
    script.onload = () => resolve();
    script.onerror = () => {
      script.remove();
      loading = null;
      reject(new Error('Google Maps failed to load'));
    };
    document.head.appendChild(script);
  });
  return loading;
}

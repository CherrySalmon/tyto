// Minimal fake of the Google Maps JavaScript API for Vitest (jsdom).
//
// Only the parts the app touches are modelled. Every created object is
// recorded on the returned registry so specs can find the map, open info
// windows, and markers, and fire listeners with `trigger(name, event)`.
//
// InfoWindow.open() attaches its content to document.body (string content via
// innerHTML) and then fires 'domready', like the real API, so both DOM-node
// and HTML-string popups can be exercised.

class Listenable {
  constructor() {
    this.listeners = {};
  }

  addListener(name, fn) {
    (this.listeners[name] ||= []).push(fn);
    return { remove: () => { this.listeners[name] = this.listeners[name].filter((f) => f !== fn); } };
  }

  trigger(name, event) {
    (this.listeners[name] || []).slice().forEach((fn) => fn(event));
  }
}

export function latLng(lat, lng) {
  return { lat: () => lat, lng: () => lng, toJSON: () => ({ lat, lng }) };
}

// A map click event. Pass `placeId` to simulate a click on a POI icon.
export function mapClick(lat, lng, placeId) {
  const event = { latLng: latLng(lat, lng), stop: vi.fn() };
  if (placeId) event.placeId = placeId;
  return event;
}

export function installGoogleMapsStub() {
  const registry = {
    maps: [],
    infoWindows: [],
    markers: [],
    // Specs replace this to control the Places library (see Slice 4).
    importLibrary: vi.fn(async (name) => { throw new Error(`library ${name} not stubbed`); }),
    openInfoWindows() {
      return this.infoWindows.filter((w) => w.isOpen);
    },
    liveMarkers() {
      return this.markers.filter((m) => m.map);
    },
  };

  class Map extends Listenable {
    constructor(el, opts = {}) {
      super();
      this.el = el;
      this.opts = opts;
      this.center = opts.center;
      this.zoom = opts.zoom;
      this.fitBounds = vi.fn((bounds) => { this.bounds = bounds; });
      registry.maps.push(this);
    }

    setCenter(center) { this.center = center; }

    panTo(center) { this.center = center; }

    setZoom(zoom) { this.zoom = zoom; }

    getZoom() { return this.zoom; }
  }

  class InfoWindow extends Listenable {
    constructor(opts = {}) {
      super();
      this.content = opts.content;
      this.position = opts.position;
      this.isOpen = false;
      this.host = null;
      registry.infoWindows.push(this);
    }

    setContent(content) {
      this.content = content;
      if (this.isOpen) this.render();
    }

    setPosition(position) { this.position = position; }

    open(mapOrOptions) {
      this.map = mapOrOptions?.map ?? mapOrOptions;
      this.anchor = mapOrOptions?.anchor;
      this.isOpen = true;
      this.render();
      this.trigger('domready');
    }

    render() {
      if (!this.host) {
        this.host = document.createElement('div');
        this.host.className = 'stub-info-window';
        document.body.appendChild(this.host);
      }
      this.host.replaceChildren();
      if (typeof this.content === 'string') this.host.innerHTML = this.content;
      else if (this.content) this.host.appendChild(this.content);
    }

    close() {
      this.isOpen = false;
      this.host?.remove();
      this.host = null;
      this.trigger('close');
    }
  }

  class Marker extends Listenable {
    constructor(opts = {}) {
      super();
      this.opts = opts;
      this.position = opts.position;
      this.title = opts.title;
      this.map = opts.map ?? null;
      registry.markers.push(this);
    }

    setMap(map) { this.map = map; }

    getPosition() { return latLng(this.position.lat, this.position.lng); }
  }

  class LatLngBounds {
    constructor() { this.points = []; }

    extend(point) {
      this.points.push(point);
      return this;
    }
  }

  const event = {
    addListenerOnce(target, name, fn) {
      const handle = target.addListener(name, (e) => { handle.remove(); fn(e); });
      return handle;
    },
  };

  globalThis.google = {
    maps: {
      Map,
      InfoWindow,
      Marker,
      LatLngBounds,
      event,
      ControlPosition: { RIGHT_BOTTOM: 'RIGHT_BOTTOM', RIGHT_CENTER: 'RIGHT_CENTER' },
      importLibrary: (name) => registry.importLibrary(name),
    },
  };

  return registry;
}

export function uninstallGoogleMapsStub() {
  delete globalThis.google;
  document.querySelectorAll('.stub-info-window').forEach((el) => el.remove());
}

// Replaces navigator.geolocation. `position` of null simulates a denied request.
export function stubGeolocation(position) {
  const geolocation = {
    getCurrentPosition: vi.fn((ok, fail) => {
      if (position) ok({ coords: { latitude: position.lat, longitude: position.lng } });
      else fail({ code: 1, PERMISSION_DENIED: 1, message: 'denied' });
    }),
  };
  Object.defineProperty(globalThis.navigator, 'geolocation', { value: geolocation, configurable: true });
  return geolocation;
}

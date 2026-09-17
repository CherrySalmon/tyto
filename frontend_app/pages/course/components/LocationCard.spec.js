import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
// Register only the Element Plus components the card uses; the app gets them
// via unplugin auto-import. `attachTo` needs Vue 3.5 (app.onUnmount) and this
// project is on Vue 3.3, so mountCard moves the root element into the
// document by hand (focus assertions need it there).
import { ElButton, ElInput } from 'element-plus';
import LocationCard from './LocationCard.vue';
import {
  installGoogleMapsStub,
  uninstallGoogleMapsStub,
  stubGeolocation,
  mapClick,
} from '../../../test/googleMapsStub.js';

const HERE = { lat: 24.79, lng: 120.99 };
const LOCATIONS = [
  { id: 1, name: 'Main Hall', latitude: 24.7937, longitude: 120.9957 },
  { id: 2, name: 'Spare Room', latitude: 24.7950, longitude: 120.9970 },
];

let gmaps;
let wrapper;

async function mountCard(locations = LOCATIONS) {
  wrapper = mount(LocationCard, {
    props: { locations },
    global: { components: { ElButton, ElInput }, config: { warnHandler: () => {} } },
  });
  document.body.appendChild(wrapper.element);
  await flushPromises();
  return wrapper;
}

function map() {
  return gmaps.maps[gmaps.maps.length - 1];
}

function popup() {
  const open = gmaps.openInfoWindows();
  return open[open.length - 1].host;
}

beforeEach(() => {
  gmaps = installGoogleMapsStub();
  stubGeolocation(HERE);
});

afterEach(() => {
  wrapper?.element.remove();
  wrapper?.unmount();
  uninstallGoogleMapsStub();
});

describe('LocationCard', () => {
  it('lists location names', async () => {
    await mountCard();
    const rows = wrapper.findAll('.location-item');
    expect(rows).toHaveLength(2);
    expect(rows[0].text()).toContain('Main Hall');
    expect(rows[1].text()).toContain('Spare Room');
  });

  it('emits delete-location from a row delete button', async () => {
    await mountCard();
    await wrapper.findAll('.location-item')[1].findAll('button').at(-1).trigger('click');
    expect(wrapper.emitted('delete-location')).toEqual([[2]]);
  });

  it('opens a popup with coordinates and a Save button on map click', async () => {
    await mountCard();
    map().trigger('click', mapClick(25.1, 121.2));
    expect(popup().textContent).toContain('25.1');
    expect(popup().textContent).toContain('121.2');
    const save = popup().querySelector('button');
    expect(save.textContent).toContain('Save Location');
    expect(save.getAttribute('type')).toBe('button');
  });

  it('shows the map even when geolocation is denied', async () => {
    stubGeolocation(null);
    await mountCard();
    expect(gmaps.maps).toHaveLength(1);
  });

  it('creates the map only once', async () => {
    await mountCard();
    for (const button of wrapper.findAll('button')) await button.trigger('click');
    await flushPromises();
    expect(gmaps.maps).toHaveLength(1);
  });

  it('has no create form outside the map, only a help note', async () => {
    await mountCard();
    const text = wrapper.text();
    expect(text).not.toContain('Create New');
    expect(text).not.toContain('Create new Location');
    expect(text).not.toContain('Modify Location');
    expect(wrapper.find('input[placeholder="Enter a name of the location"]').exists()).toBe(false);
    expect(wrapper.find('.location-help').text()).toContain('Click a spot or a place on the map to create a new location');
  });

  it('creates a location from the popup name and closes the popup', async () => {
    await mountCard();
    map().trigger('click', mapClick(25.1, 121.2));
    const input = popup().querySelector('input.location-popup-name');
    expect(document.activeElement).toBe(input);
    input.value = 'New Lab';
    popup().querySelector('button').click();

    expect(wrapper.emitted('create-location')).toEqual([[{ name: 'New Lab', latitude: 25.1, longitude: 121.2 }]]);
    expect(gmaps.openInfoWindows()).toHaveLength(0);
  });

  it('keeps the popup open and emits nothing for a blank name', async () => {
    await mountCard();
    map().trigger('click', mapClick(25.1, 121.2));
    popup().querySelector('button').click();
    expect(wrapper.emitted('create-location')).toBeUndefined();
    expect(gmaps.openInfoWindows()).toHaveLength(1);
  });

  it('shows one popup at a time', async () => {
    await mountCard();
    map().trigger('click', mapClick(25.1, 121.2));
    map().trigger('click', mapClick(25.3, 121.4));
    expect(gmaps.openInfoWindows()).toHaveLength(1);
    expect(popup().textContent).toContain('25.3');
  });

  it('does not build the map if the card is gone before Maps loads', async () => {
    wrapper = mount(LocationCard, {
      props: { locations: LOCATIONS },
      global: { components: { ElButton, ElInput }, config: { warnHandler: () => {} } },
    });
    wrapper.unmount();
    await flushPromises();
    expect(gmaps.maps).toHaveLength(0);
    wrapper = null;
  });

  it('removes its markers when unmounted', async () => {
    await mountCard();
    wrapper.element.remove();
    wrapper.unmount();
    expect(gmaps.liveMarkers()).toHaveLength(0);
    wrapper = null;
  });

  describe('after unmounting', () => {
    function unmountCard() {
      wrapper.element.remove();
      wrapper.unmount();
      wrapper = null;
    }

    it('ignores a position fix that arrives late', async () => {
      let resolvePosition;
      navigator.geolocation.getCurrentPosition.mockImplementation((ok) => { resolvePosition = ok; });
      await mountCard([]);
      const theMap = map();
      const center = theMap.center;
      unmountCard();
      resolvePosition({ coords: { latitude: HERE.lat, longitude: HERE.lng } });
      await flushPromises();
      expect(theMap.center).toBe(center);
    });

    it('does not cap the zoom when the fit settles late', async () => {
      await mountCard();
      const theMap = map();
      theMap.setZoom(21);
      unmountCard();
      theMap.trigger('idle');
      expect(theMap.getZoom()).toBe(21);
    });
  });

  describe('renaming in place', () => {
    function row(i) {
      return wrapper.findAll('.location-item')[i];
    }

    async function startRename(i) {
      await row(i).find('.location-rename-button').trigger('click');
      return row(i).find('input');
    }

    it('turns the name into a text box prefilled with the name', async () => {
      await mountCard();
      const input = await startRename(0);
      expect(input.element.value).toBe('Main Hall');
      expect(document.activeElement).toBe(input.element);
    });

    it('emits a trimmed name-only update on Enter', async () => {
      await mountCard();
      const input = await startRename(0);
      await input.setValue('  Great Hall ');
      await input.trigger('keydown', { key: 'Enter' });
      expect(wrapper.emitted('update-location')).toEqual([[1, { name: 'Great Hall' }]]);
      expect(row(0).find('input').exists()).toBe(false);
    });

    it('emits an update on blur, only once', async () => {
      await mountCard();
      const input = await startRename(1);
      await input.setValue('Quiet Room');
      await input.trigger('keydown', { key: 'Enter' });
      await input.trigger('blur');
      expect(wrapper.emitted('update-location')).toEqual([[2, { name: 'Quiet Room' }]]);
    });

    it('commits on blur', async () => {
      await mountCard();
      const input = await startRename(1);
      await input.setValue('Quiet Room');
      await input.trigger('blur');
      expect(wrapper.emitted('update-location')).toEqual([[2, { name: 'Quiet Room' }]]);
    });

    it('reverts a blank name without emitting', async () => {
      await mountCard();
      const input = await startRename(0);
      await input.setValue('   ');
      await input.trigger('keydown', { key: 'Enter' });
      expect(wrapper.emitted('update-location')).toBeUndefined();
      expect(row(0).find('input').exists()).toBe(false);
      expect(row(0).text()).toContain('Main Hall');
    });

    it('does not emit for an unchanged name', async () => {
      await mountCard();
      const input = await startRename(0);
      await input.setValue('Main Hall ');
      await input.trigger('keydown', { key: 'Enter' });
      expect(wrapper.emitted('update-location')).toBeUndefined();
    });

    it('cancels on Escape', async () => {
      await mountCard();
      const input = await startRename(0);
      await input.setValue('Other');
      await input.trigger('keydown', { key: 'Escape' });
      expect(wrapper.emitted('update-location')).toBeUndefined();
      expect(row(0).text()).toContain('Main Hall');
    });

    it('edits one row at a time', async () => {
      await mountCard();
      await startRename(0);
      await startRename(1);
      expect(wrapper.findAll('.location-item input')).toHaveLength(1);
      expect(row(1).find('input').exists()).toBe(true);
    });

    it('deleting the row being renamed sends only the delete', async () => {
      await mountCard();
      const input = await startRename(1);
      await input.setValue('Quiet Room');
      const deleteButton = row(1).findAll('button').at(-1);
      const mousedown = new MouseEvent('mousedown', { bubbles: true, cancelable: true });
      deleteButton.element.dispatchEvent(mousedown);
      // Prevented mousedown keeps focus in the input, so no blur commit fires.
      expect(mousedown.defaultPrevented).toBe(true);
      await deleteButton.trigger('click');
      await input.trigger('blur');
      expect(wrapper.emitted('delete-location')).toEqual([[2]]);
      expect(wrapper.emitted('update-location')).toBeUndefined();
    });

    it('never mutates the locations prop', async () => {
      const locations = LOCATIONS.map((l) => ({ ...l }));
      await mountCard(locations);
      const input = await startRename(0);
      await input.setValue('Changed');
      await input.trigger('keydown', { key: 'Enter' });
      expect(locations[0].name).toBe('Main Hall');
    });
  });

  describe('markers and framing', () => {
    it('draws one non-draggable marker per location, titled with its name', async () => {
      await mountCard();
      const markers = gmaps.liveMarkers();
      expect(markers.map((m) => m.title)).toEqual(['Main Hall', 'Spare Room']);
      expect(markers[0].position).toEqual({ lat: 24.7937, lng: 120.9957 });
      expect(markers.every((m) => !m.opts.draggable)).toBe(true);
    });

    it('shows the location name when a marker is clicked, without a create popup', async () => {
      await mountCard();
      gmaps.liveMarkers()[1].trigger('click');
      expect(gmaps.openInfoWindows()).toHaveLength(1);
      expect(popup().textContent).toContain('Spare Room');
      expect(popup().querySelector('input')).toBeNull();
    });

    it('shows a marker name as text, not markup', async () => {
      await mountCard([{ id: 9, name: '<img src=x onerror=alert(1)>', latitude: 1, longitude: 2 }]);
      gmaps.liveMarkers()[0].trigger('click');
      expect(popup().querySelector('img')).toBeNull();
      expect(popup().textContent).toContain('<img src=x onerror=alert(1)>');
    });

    it('closes a marker popup when locations change', async () => {
      await mountCard();
      gmaps.liveMarkers()[1].trigger('click');
      await wrapper.setProps({ locations: [LOCATIONS[0]] });
      expect(gmaps.openInfoWindows()).toHaveLength(0);
    });

    it('keeps a create popup open when locations change', async () => {
      await mountCard();
      map().trigger('click', mapClick(25.1, 121.2));
      await wrapper.setProps({ locations: [LOCATIONS[0]] });
      expect(gmaps.openInfoWindows()).toHaveLength(1);
    });

    it('replaces markers when locations change', async () => {
      await mountCard();
      await wrapper.setProps({ locations: [LOCATIONS[0]] });
      expect(gmaps.liveMarkers().map((m) => m.title)).toEqual(['Main Hall']);
    });

    it('fits the map to all locations, with padding and a zoom cap', async () => {
      await mountCard();
      expect(map().fitBounds).toHaveBeenCalledTimes(1);
      const [bounds, padding] = map().fitBounds.mock.calls[0];
      expect(bounds.points).toEqual([{ lat: 24.7937, lng: 120.9957 }, { lat: 24.7950, lng: 120.9970 }]);
      expect(padding).toBeGreaterThan(0);

      map().setZoom(21);
      map().trigger('idle');
      expect(map().getZoom()).toBe(17);
    });

    it('centers on a single location', async () => {
      await mountCard([LOCATIONS[0]]);
      expect(map().fitBounds).not.toHaveBeenCalled();
      expect(map().center).toEqual({ lat: 24.7937, lng: 120.9957 });
      expect(map().getZoom()).toBe(16);
    });

    it('frames locations that arrive after mount, and keeps them over the user position', async () => {
      await mountCard([]);
      expect(map().center).toEqual(HERE);
      await wrapper.setProps({ locations: LOCATIONS });
      expect(map().fitBounds).toHaveBeenCalledTimes(1);
    });

    it('does not re-frame on later changes', async () => {
      await mountCard();
      await wrapper.setProps({ locations: [...LOCATIONS, { id: 3, name: 'Lab', latitude: 30, longitude: 120 }] });
      expect(map().fitBounds).toHaveBeenCalledTimes(1);
    });

    it('does not move a framed map to the user position', async () => {
      let resolvePosition;
      navigator.geolocation.getCurrentPosition.mockImplementation((ok) => { resolvePosition = ok; });
      await mountCard([LOCATIONS[0]]);
      resolvePosition({ coords: { latitude: HERE.lat, longitude: HERE.lng } });
      await flushPromises();
      expect(map().center).toEqual({ lat: 24.7937, lng: 120.9957 });
    });
  });

  describe('zooming', () => {
    it('always shows zoom buttons', async () => {
      await mountCard();
      expect(map().opts.zoomControl).toBe(true);
      expect(map().opts.zoomControlOptions.position).toBe(google.maps.ControlPosition.RIGHT_BOTTOM);
      expect(map().opts.gestureHandling).toBe('cooperative');
    });

    it('explains how to zoom below the map', async () => {
      await mountCard();
      expect(wrapper.find('.map-zoom-hint').text()).toBe(
        'Zoom with the + / − buttons, Ctrl/⌘ + scroll, or pinch with two fingers.'
      );
    });
  });

  describe('clicking a known place', () => {
    const PLACE_ID = 'ChIJ-delta';

    // A fake Places API (New) `Place`; `fetchFields` resolves or rejects per
    // the given behaviour, or waits for the returned `resolve` when deferred.
    function stubPlaces({ displayName = 'Delta Building', formattedAddress = '101 University Rd', fail = false, deferred = false } = {}) {
      const calls = { ids: [], fields: [], resolvers: [] };
      class Place {
        constructor({ id }) {
          calls.ids.push(id);
        }

        fetchFields({ fields }) {
          calls.fields.push(fields);
          if (fail) return Promise.reject(new Error('Places API not enabled'));
          const fill = () => { this.displayName = displayName; this.formattedAddress = formattedAddress; };
          if (!deferred) { fill(); return Promise.resolve({ place: this }); }
          return new Promise((resolve) => calls.resolvers.push(() => { fill(); resolve({ place: this }); }));
        }
      }
      gmaps.importLibrary.mockImplementation(async (name) => {
        if (name !== 'places') throw new Error(`unexpected library ${name}`);
        return { Place };
      });
      return calls;
    }

    function input() {
      return popup().querySelector('input.location-popup-name');
    }

    it("suppresses Google's place card and opens ours at the place", async () => {
      stubPlaces();
      await mountCard();
      const click = mapClick(24.8, 121.0, PLACE_ID);
      map().trigger('click', click);
      expect(click.stop).toHaveBeenCalled();
      expect(gmaps.openInfoWindows()).toHaveLength(1);
      expect(gmaps.openInfoWindows()[0].position).toBe(click.latLng);
      expect(popup().textContent).toContain('24.8');
    });

    it('does not stop ordinary map clicks', async () => {
      await mountCard();
      const click = mapClick(24.8, 121.0);
      map().trigger('click', click);
      expect(click.stop).not.toHaveBeenCalled();
      expect(gmaps.importLibrary).not.toHaveBeenCalled();
    });

    it('shows the place name and address and saves with that name', async () => {
      const calls = stubPlaces();
      await mountCard();
      map().trigger('click', mapClick(24.8, 121.0, PLACE_ID));
      await flushPromises();

      expect(calls.ids).toEqual([PLACE_ID]);
      expect(calls.fields).toEqual([['displayName', 'formattedAddress']]);
      expect(popup().querySelector('.location-popup-title').textContent).toBe('Delta Building');
      expect(popup().querySelector('.location-popup-address').textContent).toBe('101 University Rd');
      expect(input().value).toBe('Delta Building');

      popup().querySelector('button').click();
      expect(wrapper.emitted('create-location')).toEqual([[{ name: 'Delta Building', latitude: 24.8, longitude: 121.0 }]]);
    });

    it('falls back to coordinates only when the lookup fails, logging once', async () => {
      stubPlaces({ fail: true });
      const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
      await mountCard();
      errorSpy.mockClear();

      map().trigger('click', mapClick(24.8, 121.0, PLACE_ID));
      await flushPromises();
      expect(gmaps.openInfoWindows()).toHaveLength(1);
      expect(popup().querySelector('.location-popup-loading').hidden).toBe(true);
      expect(popup().querySelector('.location-popup-title').hidden).toBe(true);
      expect(input().value).toBe('');

      map().trigger('click', mapClick(24.9, 121.1, PLACE_ID));
      await flushPromises();
      expect(errorSpy).toHaveBeenCalledTimes(1);
      errorSpy.mockRestore();
    });

    it('ignores a lookup that finishes after the user clicked elsewhere', async () => {
      const calls = stubPlaces({ deferred: true });
      await mountCard();
      map().trigger('click', mapClick(24.8, 121.0, PLACE_ID));
      await flushPromises();
      map().trigger('click', mapClick(25.5, 121.5));

      calls.resolvers[0]();
      await flushPromises();
      expect(popup().textContent).toContain('25.5');
      expect(popup().textContent).not.toContain('Delta Building');
      expect(input().value).toBe('');
    });

    it('ignores details that arrive after unmounting', async () => {
      const calls = stubPlaces({ deferred: true });
      await mountCard();
      map().trigger('click', mapClick(24.8, 121.0, PLACE_ID));
      await flushPromises();
      const content = gmaps.openInfoWindows()[0].content;
      wrapper.element.remove();
      wrapper.unmount();
      wrapper = null;

      calls.resolvers[0]();
      await flushPromises();
      expect(content.querySelector('.location-popup-title').hidden).toBe(true);
      expect(content.querySelector('.location-popup-loading').hidden).toBe(false);
    });

    it('keeps a name typed while details were loading', async () => {
      const calls = stubPlaces({ deferred: true });
      await mountCard();
      map().trigger('click', mapClick(24.8, 121.0, PLACE_ID));
      await flushPromises();
      input().value = 'Room 101';

      calls.resolvers[0]();
      await flushPromises();
      expect(input().value).toBe('Room 101');
      expect(popup().querySelector('.location-popup-title').textContent).toBe('Delta Building');
    });
  });
});

import { describe, it, expect, vi } from 'vitest';
import { buildLocationPopup, showPlaceDetails } from './locationPopup.js';

const LAT_LNG = { lat: 24.7937, lng: 120.9957 };

function build(opts = {}) {
  return buildLocationPopup({ latLng: LAT_LNG, onSave: vi.fn(), ...opts });
}

function saveButton(popup) {
  return [...popup.querySelectorAll('button')].find((b) => b.textContent.includes('Save Location'));
}

function nameInput(popup) {
  return popup.querySelector('input.location-popup-name');
}

function enter(input) {
  input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
}

describe('buildLocationPopup', () => {
  it('shows the coordinates', () => {
    const popup = build();
    expect(popup.textContent).toContain('Latitude: 24.7937');
    expect(popup.textContent).toContain('Longitude: 120.9957');
  });

  it('has a non-submitting Save Location button that calls onSave', () => {
    const onSave = vi.fn();
    const popup = build({ onSave });
    const save = saveButton(popup);
    expect(save.type).toBe('button');
    nameInput(popup).value = 'Main Hall';
    save.click();
    expect(onSave).toHaveBeenCalledTimes(1);
  });

  it('has a name input, empty by default or prefilled from name', () => {
    expect(nameInput(build()).value).toBe('');
    expect(nameInput(build({ name: 'Library' })).value).toBe('Library');
  });

  it('passes the trimmed name to onSave', () => {
    const onSave = vi.fn();
    const popup = build({ onSave });
    nameInput(popup).value = '  Main Hall  ';
    saveButton(popup).click();
    expect(onSave).toHaveBeenCalledWith({ name: 'Main Hall' });
  });

  it('saves when Enter is pressed in the name input', () => {
    const onSave = vi.fn();
    const popup = build({ onSave });
    nameInput(popup).value = 'Main Hall';
    enter(nameInput(popup));
    expect(onSave).toHaveBeenCalledWith({ name: 'Main Hall' });
  });

  it('shows an error and does not save a blank name', () => {
    const onSave = vi.fn();
    const popup = build({ onSave });
    const error = popup.querySelector('.location-popup-error');
    expect(error.hidden).toBe(true);

    nameInput(popup).value = '   ';
    saveButton(popup).click();
    enter(nameInput(popup));

    expect(onSave).not.toHaveBeenCalled();
    expect(error.hidden).toBe(false);
    expect(error.textContent).toContain('Enter a name');
  });
});

describe('place details in the popup', () => {
  const PLACE = { name: 'Delta Building', address: '101 University Rd, Hsinchu' };

  function loading(popup) {
    return popup.querySelector('.location-popup-loading');
  }

  it('shows a loading line only while place details load', () => {
    expect(loading(build()).hidden).toBe(true);
    expect(loading(build({ loadingPlace: true })).hidden).toBe(false);
  });

  it('shows the place name and address and prefills the name', () => {
    const popup = build({ loadingPlace: true });
    showPlaceDetails(popup, PLACE);
    expect(loading(popup).hidden).toBe(true);
    expect(popup.querySelector('.location-popup-title').textContent).toBe('Delta Building');
    expect(popup.querySelector('.location-popup-address').textContent).toBe('101 University Rd, Hsinchu');
    expect(nameInput(popup).value).toBe('Delta Building');
  });

  it('keeps a name the user already typed', () => {
    const popup = build({ loadingPlace: true });
    nameInput(popup).value = 'Room 101';
    showPlaceDetails(popup, PLACE);
    expect(nameInput(popup).value).toBe('Room 101');
  });

  it('only stops loading when there are no details', () => {
    const popup = build({ loadingPlace: true });
    showPlaceDetails(popup, null);
    expect(loading(popup).hidden).toBe(true);
    expect(popup.querySelector('.location-popup-title').hidden).toBe(true);
    expect(popup.querySelector('.location-popup-address').hidden).toBe(true);
    expect(nameInput(popup).value).toBe('');
  });

  it('renders place text as text, not markup', () => {
    const popup = build({ loadingPlace: true });
    showPlaceDetails(popup, { name: '<img src=x onerror=alert(1)>', address: '<b>bold</b>' });
    expect(popup.querySelector('img')).toBeNull();
    expect(popup.querySelector('b')).toBeNull();
    expect(popup.textContent).toContain('<img src=x onerror=alert(1)>');
  });
});

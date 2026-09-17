// Content for the Google Maps InfoWindow on the Locations tab.
//
// Built with DOM APIs rather than an HTML string: text is set with
// textContent (place names can't inject markup) and listeners are attached
// directly (no 'domready' + getElementById lookup). Buttons are
// type="button" so they never submit a surrounding form (see the Firefox
// location hotfix).

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function hiddenElement(tag, className, text) {
  const node = element(tag, className, text);
  node.hidden = true;
  return node;
}

// Returns the popup element. `onSave({ name })` is called with the trimmed
// name; a blank name shows an inline error instead. With `loadingPlace`, the
// popup shows a loading line until showPlaceDetails() is called.
export function buildLocationPopup({ latLng, name = '', loadingPlace = false, onSave }) {
  const popup = element('div', 'location-popup');
  const title = hiddenElement('strong', 'location-popup-title');
  const address = hiddenElement('p', 'location-popup-address');
  const loading = hiddenElement('p', 'location-popup-loading', 'Loading place details…');
  loading.hidden = !loadingPlace;

  const input = element('input', 'location-popup-name');
  input.type = 'text';
  input.placeholder = 'Location name';
  input.maxLength = 200;
  input.value = name;
  input.setAttribute('aria-label', 'Location name');

  const error = hiddenElement('p', 'location-popup-error', 'Enter a name for this location.');

  const save = element('button', 'info-button', 'Save Location');
  save.type = 'button';

  const submit = () => {
    const trimmed = input.value.trim();
    error.hidden = trimmed !== '';
    if (trimmed === '') {
      input.focus();
      return;
    }
    onSave({ name: trimmed });
  };
  save.addEventListener('click', submit);
  input.addEventListener('keydown', (event) => {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    submit();
  });

  popup.append(
    title,
    address,
    loading,
    input,
    error,
    element('p', 'location-popup-coord', `Latitude: ${latLng.lat}`),
    element('p', 'location-popup-coord', `Longitude: ${latLng.lng}`),
    save,
  );
  return popup;
}

// Ends the loading state of a popup from buildLocationPopup. With `place`
// ({ name, address }), shows its details and prefills the name unless the
// user already typed one; with null (lookup failed), only stops loading.
export function showPlaceDetails(popup, place) {
  popup.querySelector('.location-popup-loading').hidden = true;
  if (!place) return;

  const fill = (selector, text) => {
    const node = popup.querySelector(selector);
    node.textContent = text || '';
    node.hidden = !text;
  };
  fill('.location-popup-title', place.name);
  fill('.location-popup-address', place.address);

  const input = popup.querySelector('.location-popup-name');
  if (input.value.trim() === '' && place.name) input.value = place.name;
}

// Read-only popup for an existing location's marker.
export function buildLocationInfo({ name }) {
  const info = element('div', 'location-popup');
  info.append(element('strong', 'location-popup-title', name));
  return info;
}

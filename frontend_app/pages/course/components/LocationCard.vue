<template>
    <div class="course-card-container">
        <div class="course-content-title">Location</div>
        <div v-for="(location, idx) in locations" :key="location.id" class="location-item">
            <span class="location-index">{{ idx+1 }}:</span>
            <el-input
                v-if="renamingId === location.id"
                ref="renameInput"
                v-model="renameText"
                size="small"
                maxlength="200"
                aria-label="Location name"
                class="location-rename-input"
                @keydown.enter.prevent="commitRename(location)"
                @keydown.esc.prevent="cancelRename"
                @blur="commitRename(location)"
            />
            <template v-else>
                <span class="location-name">{{ location.name }}</span>
                <el-button type="primary" icon="Edit" circle class="location-icon location-rename-button"
                    :aria-label="`Rename ${location.name}`" @click="startRename(location)"/>
            </template>
            <!-- mousedown.prevent keeps focus in a rename box, so its blur doesn't save a rename of a row being deleted -->
            <el-button type="danger" icon="Delete" circle class="location-icon"
                :aria-label="`Delete ${location.name}`" @mousedown.prevent @click.stop="deleteLocation(location)"/>
        </div>

        <div class="map-section">
            <p class="location-help">Click a spot or a place on the map to create a new location.</p>
            <div ref="map" class="map-container"></div>
            <p class="map-zoom-hint">Zoom with the + / − buttons, Ctrl/⌘ + scroll, or pinch with two fingers.</p>
        </div>
    </div>
</template>

<script>
import { buildLocationPopup, buildLocationInfo, showPlaceDetails } from '@/lib/locationPopup.js'
import { getCurrentPosition } from '@/lib/geolocation.js'
import { loadGoogleMaps } from '@/lib/googleMaps.js'
import { framingFor, hasCoordinates, DEFAULT_CENTER, SINGLE_LOCATION_ZOOM } from '@/lib/mapFraming.js'

const FIT_PADDING = 48
const MAX_FIT_ZOOM = 17
// Places API (New) fields shown for a clicked place; each lookup is billed.
const PLACE_FIELDS = ['displayName', 'formattedAddress']

export default {
    // SingleCourse's RouterView passes every tab's props and listeners; keep
    // the ones this card does not declare off the root element.
    inheritAttrs: false,
    emits: ['create-location', 'update-location', 'delete-location'],
    props: {
      locations: Array
    },

    data() {
        return {
            renamingId: null,
            renameText: ''
        }
    },

    created() {
        // Google Maps objects stay non-reactive (Vue proxies break them).
        this.map = null
        this.infoWindow = null
        this.markers = []
        // The map is framed once, on the first non-empty list of locations, so
        // later creates/renames/deletes don't move the view.
        this.framed = false
        // Increments per create popup, so a slow place lookup can't fill a newer one.
        this.popupSerial = 0
        this.placesErrorLogged = false
        this.unmounted = false
        // 'marker' or 'create': which kind of popup the shared InfoWindow shows.
        this.popupKind = null
    },

    async mounted() {
        try {
            await loadGoogleMaps();
        } catch (error) {
            console.error(error);
            return;
        }
        // The user may have left the tab while Maps was loading.
        if (this.unmounted) return;
        this.initMap();
        this.showLocations();
        this.centerOnCurrentPosition();
    },

    beforeUnmount() {
        this.unmounted = true
        this.markers.forEach((marker) => marker.setMap(null))
        this.markers = []
        this.infoWindow?.close()
    },

    watch: {
        locations() {
            if (this.map) this.showLocations();
        }
    },

    methods: {
        async centerOnCurrentPosition() {
            try {
                const { coords } = await getCurrentPosition();
                if (this.unmounted || this.framed) return;
                this.applyFraming(framingFor([], { lat: coords.latitude, lng: coords.longitude }));
            } catch (error) {
                console.error('Error getting location', error);
            }
        },
        initMap() {
            this.map = new google.maps.Map(this.$refs.map, {
                zoom: SINGLE_LOCATION_ZOOM,
                center: DEFAULT_CENTER,
                zoomControl: true,
                zoomControlOptions: { position: google.maps.ControlPosition.RIGHT_BOTTOM },
                // Ctrl/⌘ + scroll or two-finger gestures, so the page still scrolls
                // past the map; the hint below the map says so.
                gestureHandling: 'cooperative',
            });
            this.infoWindow = new google.maps.InfoWindow();
            this.map.addListener("click", (event) => this.onMapClick(event));
        },
        showLocations() {
            // A marker popup may show a renamed or deleted location; a create
            // popup stays open so a name being typed isn't lost.
            if (this.popupKind === 'marker') this.infoWindow.close();
            this.markers.forEach((marker) => marker.setMap(null));
            this.markers = (this.locations || [])
                .filter(hasCoordinates)
                .map((location) => this.addMarker(location));

            if (!this.framed && this.markers.length > 0) {
                this.framed = true;
                this.applyFraming(framingFor(this.locations));
            }
        },
        addMarker(location) {
            const marker = new google.maps.Marker({
                map: this.map,
                position: { lat: location.latitude, lng: location.longitude },
                title: location.name,
            });
            marker.addListener('click', () => {
                this.infoWindow.close();
                this.popupKind = 'marker';
                this.infoWindow.setContent(buildLocationInfo({ name: location.name }));
                this.infoWindow.open({ map: this.map, anchor: marker });
            });
            return marker;
        },
        applyFraming(framing) {
            if (framing.kind === 'center') {
                this.map.setCenter(framing.center);
                this.map.setZoom(framing.zoom);
                return;
            }
            const bounds = new google.maps.LatLngBounds();
            framing.points.forEach((point) => bounds.extend(point));
            // Cap the zoom once the fit settles, so close-together locations
            // don't zoom in past street level.
            google.maps.event.addListenerOnce(this.map, 'idle', () => {
                if (this.unmounted) return;
                if (this.map.getZoom() > MAX_FIT_ZOOM) this.map.setZoom(MAX_FIT_ZOOM);
            });
            this.map.fitBounds(bounds, FIT_PADDING);
        },
        onMapClick(event) {
            if (!event.placeId) {
                this.openCreatePopup(event.latLng);
                return;
            }
            // A click on a Google place icon: replace Google's own place card
            // with our popup, then fill in the place's details.
            event.stop();
            this.openPlacePopup(event.placeId, event.latLng);
        },
        async openPlacePopup(placeId, position) {
            const content = this.openCreatePopup(position, { loadingPlace: true });
            const serial = this.popupSerial;
            const place = await this.lookupPlace(placeId);
            if (this.unmounted || serial !== this.popupSerial) return;
            showPlaceDetails(content, place);
        },
        async lookupPlace(placeId) {
            try {
                const { Place } = await google.maps.importLibrary('places');
                const place = new Place({ id: placeId });
                await place.fetchFields({ fields: PLACE_FIELDS });
                return { name: place.displayName, address: place.formattedAddress };
            } catch (error) {
                if (!this.placesErrorLogged) {
                    this.placesErrorLogged = true;
                    console.error('Place details unavailable (is Places API (New) enabled for this key?)', error);
                }
                return null;
            }
        },
        openCreatePopup(position, { loadingPlace = false } = {}) {
            this.popupSerial += 1;
            const latLng = position.toJSON();
            const content = buildLocationPopup({
                latLng,
                loadingPlace,
                onSave: ({ name }) => this.createLocation(name, latLng),
            });
            this.infoWindow.close();
            this.popupKind = 'create';
            this.infoWindow.setContent(content);
            this.infoWindow.setPosition(position);
            google.maps.event.addListenerOnce(this.infoWindow, 'domready', () => {
                content.querySelector('input')?.focus();
            });
            this.infoWindow.open(this.map);
            return content;
        },
        createLocation(name, latLng) {
            this.$emit('create-location', { name, latitude: latLng.lat, longitude: latLng.lng });
            this.infoWindow.close();
        },
        deleteLocation(location) {
            if (this.renamingId === location.id) this.cancelRename()
            this.$emit('delete-location', location.id)
        },
        startRename(location) {
            this.renamingId = location.id
            this.renameText = location.name
            this.$nextTick(() => this.$refs.renameInput?.[0]?.focus())
        },
        commitRename(location) {
            if (this.renamingId !== location.id) return
            const name = this.renameText.trim()
            this.cancelRename()
            // A blank name reverts to the original; an unchanged one is a no-op.
            if (name === '' || name === location.name) return
            this.$emit('update-location', location.id, { name })
        },
        cancelRename() {
            this.renamingId = null
            this.renameText = ''
        }
    }
}
</script>
<style scoped>
.course-card-container {
    text-align: left;
}

.location-item {
    display: flex;
    align-items: center;
    gap: 5px;
    margin: 20px;
}

.location-rename-input {
    width: 240px;
}

.location-icon {
    cursor: pointer;
}

.map-section {
    margin: 30px 20px;
}

.location-help {
    margin-bottom: 10px;
    color: #606266;
}

.map-container {
    width: 90%;
    height: 500px;
}

.map-zoom-hint {
    margin-top: 6px;
    font-size: 12px;
    color: #909399;
}

@media (max-width: 640px) {
    .map-container {
        width: 100%;
        height: 300px;
    }
    .map-section {
        margin: 0;
    }
}
</style>

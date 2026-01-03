<template>
    <div class="course-card-container">
        <div class="course-content-title">Location</div>
        <div v-for="(location, idx) in locations" :key="location.id" class="location-item">
            {{ idx+1 }}: {{ location.name }}
            <el-button type="primary" icon="Edit" circle class="location-icon" @click="clickModify(location)"/>
            <el-button type="danger" icon="Delete" circle @click.stop="$emit('delete-location', location.id)" class="location-icon"/>
        </div>
        <el-button type="primary" @click="clickCreate" icon="AddLocation" style="margin: 0px 20px 20px 20px;">Create New</el-button>

        <div class="form-container">
            <h1 style="margin-bottom: 10px;">{{modifiedId?'Modify Location':'Create new Location'}}</h1>
            <el-form ref="locationForm" :model="locationForm">
                <el-form-item label="Name">
                    <el-input placeholder="Enter a name of the location" v-model="locationForm.name" style="width: 200px;"></el-input>
                </el-form-item>
                <div id="map" class="map-container"></div>
            </el-form>
        </div>

    </div>
</template>
  
<script>
export default {
    emits: ['create-event', 'edit-event', 'delete-event', 'create-location', 'update-location', 'delete-location', 'new-enrolls', 'update-enrollment', 'delete-enrollment'],
    props: {
      attendanceEvents: Object,
      locations: Array,
      enrollments: Object, 
      currentRole: String
    },
    name: 'GoogleMapComponent',

    async mounted() {
        await this.loadGoogleMapsApi();
        await this.getCurrentLocation();
    },

    data() {
        return {
            locationForm: {
                name: '',
                latitude: '',
                longitude: ''
            },
            currentLocationData: {},
            modifiedId: null
        }
    },
    watch: {

    },
    methods: {
        async loadGoogleMapsApi() {
            if (typeof google === "undefined" || typeof google.maps === "undefined") {
                const script = document.createElement('script');
                script.src = `https://maps.googleapis.com/maps/api/js?key=${process.env.VUE_APP_GOOGLE_MAP_KEY}`;
                document.head.appendChild(script);
                await new Promise((resolve) => {
                    script.onload = resolve;
                });
            }
        },
        async getCurrentLocation() {
            if (navigator.geolocation) {
                navigator.geolocation.getCurrentPosition(async (position) => {
                    const { latitude, longitude } = position.coords;
                    this.currentLocationData = {
                        latitude: latitude,
                        longitude: longitude
                    };
                    this.locationForm = { ...this.currentLocationData };
                    
                    // Initialize the map here to ensure it's done after obtaining the location
                    await this.initMap();
                }, (error) => {
                    console.error('Error getting location', error);
                });
            } else {
                console.error('Geolocation is not supported by this browser.');
            }
        },
        async initMap() {
            if(!this.locationForm.latitude) {
                this.locationForm = {
                    latitude: 24.793701145,
                    longitude: 120.9957896
                }
            }
            const myLatlng = { lat: this.locationForm.latitude, lng: this.locationForm.longitude };
            const map = new google.maps.Map(document.getElementById("map"), {
                zoom: 16,
                center: myLatlng,
            });

            // Create the initial InfoWindow.
            let infoWindow = new google.maps.InfoWindow({
                content: "Click the map to get Lat/Lng!",
                position: myLatlng,
            });

            infoWindow.open(map);

            // Configure the click listener.
            map.addListener("click", (mapsMouseEvent) => {
                const latLng = mapsMouseEvent.latLng.toJSON();

                // Close the current InfoWindow.
                infoWindow.close();

                const contentString =
                    `<div style="text-align: center;">
                        <p style="margin: 10px 15px 5px;">Latitude: ${latLng.lat}</p>
                        <p style="margin-bottom: 10px;">Longitude: ${latLng.lng}</p>
                        <button id="saveLocationBtn" class="info-button">Save Location</button>
                    </div>`;

                // Create a new InfoWindow.
                infoWindow = new google.maps.InfoWindow({
                    position: mapsMouseEvent.latLng,
                    content: contentString,
                });
                infoWindow.addListener('domready', () => {
                    document.getElementById("saveLocationBtn").addEventListener("click", () => {
                        this.saveLocation(latLng);
                    });
                });
                infoWindow.open(map);
            });
        },
        saveLocation(latLng) {
            const locationData = {
                name: this.locationForm.name, // Use the name from the form
                latitude: latLng.lat,
                longitude: latLng.lng
            };
            if (this.modifiedId) {
                this.$emit('update-location', this.modifiedId, locationData);
            }
            else {
                this.$emit('create-location', locationData);
            }
            this.locationForm = {}
        },
        clickCreate() {
            this.modifiedId = null
            this.locationForm = this.currentLocationData
            this.initMap()
        },
        clickModify(location) {
            this.modifiedId = location.id
            this.locationForm = location
            this.initMap()
        }
    }
}
</script>
<style scoped>
.course-card-container {
    text-align: left;
}
.form-container {
    width: 100%;
    margin: 30px 20px;
}

.location-item {
    display: flex;
    align-items: center;
    margin: 20px;
}

.location-icon {
    cursor: pointer;
    margin-left: 5px;
}
.map-container {
    width: 90%;
    height: 500px;
}
@media (max-width: 640px) {
    .map-container {
        width: 100%;
        height: 300px;
    }
    .form-container {
        margin: 0;
    }
}
</style>
<template>
    <div id="map" style="height: 600px; width: 100%;"></div>
</template>

<script>
import { loadGoogleMaps } from '@/lib/googleMaps.js'

  export default {
    emits: [],
    props: {
      eventAttendances: Array,
      event: Object
    },
    data() {
        return {
        }
    },
    mounted() {
        this.initMap();
    },
    methods: {
        async initMap() {
            await loadGoogleMaps();

            const center = {
                lat: this.event.latitude,
                lng: this.event.longitude,
            };

            const map = new google.maps.Map(document.getElementById("map"), {
                zoom: 18,
                center: center,
                mapId: '82dda74d2d05b087'
            });

            this.eventAttendances.forEach(attendance => {
                new google.maps.Marker({
                position: { lat: attendance.latitude, lng: attendance.longitude },
                map: map,
                title: attendance.name,
                });
            });
        }
    }
}
</script>
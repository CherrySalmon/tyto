<template>
    <div id="map" style="height: 600px; width: 100%;"></div>
</template>

<script>

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
        async initMap() {
            await this.loadGoogleMapsApi();

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
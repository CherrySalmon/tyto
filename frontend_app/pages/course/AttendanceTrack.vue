<template>
    <div>
        <div v-loading.fullscreen.lock="fullscreenLoading"></div>
        <div v-if="events">
            <el-card v-for="event in events" :key="event.id" class="box-card"
                style="width: 60%; margin-top: 10%; margin-left: 20%;">
                <!-- <el-card class="box-card" style="width: 60%; margin-top: 10%; margin-left: 20%;"> -->
                <div slot="header" class="clearfix">
                    <span>{{ event.name }}</span>
                </div><br />
                <div>
                    <p>Course: {{  event.course_name || 'N/A' }}</p>
                    <p>Location: {{ event.location_name || 'N/A' }}</p>
                    <p>Start Time: {{ event.start_at || 'N/A' }}</p>
                    <p>End Time: {{ event.end_at || 'N/A' }}</p>
                    <!-- <p>Location: {{ event.location_name || 'N/A' }}</p> -->
                </div>
                <br />
                <div v-if="event.isAttendanceExisted">
                  <el-button type="success" disabled>Attendance Recorded</el-button>
                </div>
                <div v-else>
                  <el-button type="info" @click="getLocation(event)">Mark Attendance</el-button>
                </div>
            </el-card>
        </div>
    </div>
</template>
  
<script>
import axios from 'axios';
import cookieManager from '../../lib/cookieManager';
import { ElMessageBox, ElLoading } from 'element-plus';

export default {
    name: 'AttendanceTrack',

    data() {
        return {
            fullscreenLoading: false,
            events: {},
            course_id: '',
            location_name: '',
            accountCredential: '',
            isEventDataFetched: false,
            locationText: '', // Initialize location text
            errMessage: '',
            latitude: 0,
            longitude: 0,
            location: {},
            account: {},
        };
    },
    watch: {
        // Watch the `event` object for changes
        events: {
            handler(newVal) {
                // If event data is still not present after being fetched, redirect
                if ((!newVal || Object.keys(newVal).length === 0) && this.isEventDataFetched) {
                    console.log('No event data found, redirecting...');
                    ElNotification({
                        title: 'Warning',
                        message: 'No event data found, redirecting...',
                        type: 'warning',
                    })
                    setTimeout(() => {
                        this.fullscreenLoading = false;
                        this.$router.push('/course/' + this.$route.params.id);
                    }, 3000);
                } else {
                    console.log('Event data found:', newVal);
                    this.fullscreenLoading = false
                }
            },
            deep: true, // This ensures the watcher reacts to changes in object properties
            immediate: true, // This ensures the handler is called immediately with the current value upon creation
        }
    },

    created() {
        this.accountCredential = cookieManager.getCookie('account_credential');
        this.account = cookieManager.getAccount();
        this.course_id = this.$route.params.id;
        this.fullscreenLoading = true;
        this.fetchEventData();
    },
    methods: {
        async fetchEventData() { // Mark the method as async
            try {
                const response = await axios.get(`/api/current_event/`, {
                    headers: {
                        Authorization: `Bearer ${this.accountCredential}`,
                    },
                });
                console.log('Event Data Fetched Successfully:', response.data.data);
                this.isEventDataFetched = true;

                const matchingAttendancesEvents = response.data.data.filter(attendance => 
                    parseInt(attendance.course_id) == this.course_id);

                this.events = await Promise.all(matchingAttendancesEvents.map(async (event) => {
                    // Use getCourseName to fetch the course name asynchronously
                    const course_name = await this.getCourseName(event.course_id);
                    const location_name = await this.getLocationName(event);
                    const isAttendanceExisted = await this.findAttendance(event);
                    return {
                        ...event,
                        start_at: this.getLocalDateString(event.start_at),
                        end_at: this.getLocalDateString(event.end_at),
                        course_name: course_name,
                        location_name: location_name,
                        isAttendanceExisted: isAttendanceExisted,
                    };
                }));
            } catch (error) {
                console.error('Error fetching event data:', error);
            }
        },
        getCourseName(course_id) {
            return axios.get(`/api/course/${course_id}`, {
                headers: {
                    Authorization: `Bearer ${this.accountCredential}`,
                },
            }).then(response => response.data.data.name) // Assuming the response has this structure
            .catch(error => {
                console.error('Error fetching course name:', error);
                return 'Error fetching course name'; // Provide a fallback or error message
            });
        },
        getLocationName(event) {
            return axios.get(`/api/course/${event.course_id}/location/${event.location_id}`, {
                headers: {
                    Authorization: `Bearer ${this.accountCredential}`,
                },
            }).then(response => response.data.data.name) // Assuming the response has this structure
            .catch(error => {
                console.error('Error fetching location name:', error);
                return 'Error fetching location name'; // Provide a fallback or error message
            });
        },
        getLocalDateString(utcStr) {
            if (!utcStr) {
                return 'Invalid Date';
            }

            // Backend now returns ISO 8601 (UTC) strings, e.g. "2026-01-20T08:00:00Z"
            const date = new Date(utcStr);
            if (Number.isNaN(date.getTime())) {
                console.error('Invalid date value:', utcStr);
                return 'Invalid Date';
            }

            // Formatting the Date object to a local date string
            return date.getFullYear()
                + '-' + String(date.getMonth() + 1).padStart(2, '0')
                + '-' + String(date.getDate()).padStart(2, '0')
                + ' ' + String(date.getHours()).padStart(2, '0')
                + ':' + String(date.getMinutes()).padStart(2, '0');
        },
        getLocation(event) {
            console.log("start getting location");
            // Start the loading screen
            const loading = ElLoading.service({
                lock: true,
                text: 'Loading',
                background: 'rgba(0, 0, 0, 0.7)',
            });
            if (navigator.geolocation) {
                navigator.geolocation.getCurrentPosition(
                    position => this.showPosition(position, loading, event),
                    error => this.showError(error, loading)
                );
            } else {
                this.locationText = "Geolocation is not supported by this browser.";
            }
        },
        showPosition(position, loading, event) {
            this.locationText = `Latitude: ${position.coords.latitude}, Longitude: ${position.coords.longitude}, Accuracy: ${position.coords.accuracy}`;

            this.latitude = position.coords.latitude;
            this.longitude = position.coords.longitude;


            const course_id = event.course_id;
            const location_id = event.location_id;

            axios.get(`/api/course/${course_id}/location/${location_id}`, {
                headers: {
                    Authorization: `Bearer ${this.accountCredential}`,
                },
            }).then(response => {
                this.location = response.data.data;
                this.isEventDataFetched = true;

                const range = 0.0005
                const minLat = this.location.latitude - range
                const maxLat = this.location.latitude + range
                const minLng = this.location.longitude - range
                const maxLng = this.location.longitude + range

                // Check if the current position is within the range
                if (this.latitude >= minLat && this.latitude <= maxLat && this.longitude >= minLng && this.longitude <= maxLng) {
                    // Call your API if within the range
                    this.postAttendance(loading, event);
                } else {
                    ElMessageBox.alert('You are not in the right location', 'Failed', {
                        confirmButtonText: 'OK',
                        type: 'error',
                    })
                    loading.close();
                }
            }).catch(error => {
                console.error('Error fetching event:', error);
            });
        },
        showError(error) {
            switch (error.code) {
                case error.PERMISSION_DENIED:
                    this.errMessage = "User denied the request for Geolocation.";
                    break;
                case error.POSITION_UNAVAILABLE:
                    this.errMessage = "Location information is unavailable.";
                    break;
                case error.TIMEOUT:
                    this.errMessage = "The request to get user location timed out.";
                    break;
                default:
                    this.errMessage = "An unknown error occurred.";
                    break;
            }
        },
        postAttendance(loading, event) {
            // Use your actual course ID here
            const courseId = event.course_id; // Example course ID
            axios.post(`/api/course/${courseId}/attendance`, {
                // Include any required data here
                event_id: event.id,
                name: event.name,
                latitude: this.latitude,
                longitude: this.longitude,
            }, {
                headers: {
                    Authorization: `Bearer ${this.accountCredential}`,
                }
            })
                .then(response => {
                    // Handle success
                    console.log('Attendance recorded successfully', response.data);
                    this.updateEventAttendanceStatus(event.id, true);
                    ElMessageBox.alert('Attendance recorded successfully', 'Success', {
                        confirmButtonText: 'OK',
                        type: 'success',
                    })
                })
                .catch(error => {
                    // Handle error
                    console.error('Error recording attendance', error);
                    this.updateEventAttendanceStatus(event.id, true);
                    ElMessageBox.alert('Attendance has already recorded', 'Warning', {
                        confirmButtonText: 'OK',
                        type: 'warning',
                    })
                }).finally(() => {
                    loading.close();
                });
        },
        findAttendance(event) {
            // Return a new promise that resolves with the boolean result
            return new Promise((resolve, reject) => {
                axios.get(`/api/course/${event.course_id}/attendance`, {
                    headers: {
                        Authorization: `Bearer ${this.accountCredential}`,
                    },
                }).then(response => {
                    const accountId = this.account.id; // Ensure this is set correctly
                    const eventId = event.id;
                    const matchingAttendances = response.data.data.filter(attendance => 
                        parseInt(attendance.account_id) == accountId && parseInt(attendance.event_id) == eventId
                    );

                    // Resolve the promise with true if any attendances match, otherwise false
                    resolve(matchingAttendances.length > 0);
                }).catch(error => {
                    console.error('Error fetching attendance data:', error);
                    // Reject the promise in case of an error
                    reject(error);
                });
            });
        },

        updateEventAttendanceStatus(eventId, status) {
            const eventIndex = this.events.findIndex(event => event.id === eventId);
            if (eventIndex !== -1) {
                this.events[eventIndex].isAttendanceExisted = status;
            }
        }
    },
};
</script>
  
<style>
.el-loading-spinner {
    filter: hue-rotate(180deg);
}
</style>
  
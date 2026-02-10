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
import api from '@/lib/tytoApi';
import session from '../../lib/session';
import { formatLocalDateTime } from '../../lib/dates';
import { recordAttendance } from '../../lib/attendance';
import { ElMessageBox, ElLoading } from 'element-plus';

export default {
    name: 'AttendanceTrack',

    data() {
        return {
            fullscreenLoading: false,
            events: {},
            course_id: '',
            location_name: '',
            isEventDataFetched: false,
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
        this.account = session.getAccount();
        this.course_id = this.$route.params.id;
        this.fullscreenLoading = true;
        this.fetchEventData();
    },
    methods: {
        async fetchEventData() {
            try {
                const response = await api.get(`/current_event/`);
                console.log('Event Data Fetched Successfully:', response.data.data);
                this.isEventDataFetched = true;

                const matchingEvents = response.data.data.filter(event =>
                    parseInt(event.course_id) == this.course_id);

                this.events = matchingEvents.map(event => ({
                    ...event,
                    start_at: formatLocalDateTime(event.start_at),
                    end_at: formatLocalDateTime(event.end_at),
                    isAttendanceExisted: event.user_attendance_status,
                }));
            } catch (error) {
                console.error('Error fetching event data:', error);
            }
        },
        async getLocation(event) {
            const loading = ElLoading.service({
                lock: true,
                text: 'Loading',
                background: 'rgba(0, 0, 0, 0.7)',
            });
            try {
                await recordAttendance(event, {
                    onSuccess: (eventId) => {
                        this.updateEventAttendanceStatus(eventId, true);
                        ElMessageBox.alert('Attendance recorded successfully', 'Success', {
                            confirmButtonText: 'OK',
                            type: 'success',
                        });
                    },
                    onError: (message) => {
                        ElMessageBox.alert(message, 'Failed', {
                            confirmButtonText: 'OK',
                            type: 'error',
                        });
                    },
                    onDuplicate: (eventId) => {
                        this.updateEventAttendanceStatus(eventId, true);
                        ElMessageBox.alert('Attendance has already been recorded', 'Warning', {
                            confirmButtonText: 'OK',
                            type: 'warning',
                        });
                    },
                });
            } finally {
                loading.close();
            }
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
  
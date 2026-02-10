<template>
  <div class="event-card-container course-card-container">
    <div class="course-content-title">Attendance Events</div>
    <div class="course-download-btn">
      <el-button color="#824533" :dark="true" @click="downloadReport()">Download Record</el-button>
    </div>
    
    <el-card class="event-item" shadow="hover" @click.stop="$emit('create-event')">
      <h3>Create Event</h3>
      <el-icon :size="24" style="margin-top: 10px;"><DocumentAdd /></el-icon>
    </el-card>
    <el-card v-for="event in attendanceEvents" :key="event.id" class="event-item" shadow="always" style="background-color: #f2f2f2">
      <div style="">
        <h3>{{ event.name }}</h3>
        <p>Location: {{ getEventLocationName(event.location_id) }}</p>
        <!-- <p>Start Time: {{ event.start_at }}</p>
        <p>End Time: {{ event.end_at }}</p> -->
        <el-icon :size="18" @click="showAttendanceMap(event)"><MapLocation /></el-icon>
        <el-icon :size="18" @click="$emit('edit-event', event.id)" style="margin-left: 10px;">
          <Edit />
        </el-icon>
        <span style="margin-left: 10px;"></span>
        <el-icon :size="18" @click.stop="$emit('delete-event', event.id)">
          <Delete />
        </el-icon>
      </div>   
    </el-card>
    <el-dialog v-model="attendanceMapVisible" :title="selectedEvent.name"  :width="dialogWidth">
      <AttendanceMap v-if="attendanceMapVisible" :eventAttendances="eventAttendances" :event="selectedEvent"></AttendanceMap>
    </el-dialog>
  </div>
</template>
  
<script>
import api from '@/lib/tytoApi';
import cookieManager from '../../../lib/cookieManager';
import downloadFile from '../../../lib/downloadFile';
import AttendanceMap from './AttendanceMap.vue';
  export default {
    emits: ['create-event', 'edit-event', 'delete-event', 'create-location', 'update-location', 'delete-location', 'new-enrolls', 'update-enrollment', 'delete-enrollment'],
    props: {
      course: Object,
      attendanceEvents: Object,
      locations: Array,
      enrollments: Object, 
      currentRole: String
    },
    components: {AttendanceMap},
    data() {
        return {
          account: {
            roles: [],
            credential: ''
          },
          selectedEvent: {},
          eventAttendances: '',
          attendanceMapVisible: false,
          dialogWidth: "960px",
        }
    },
    created() {
      this.account = cookieManager.getAccount();
    },
    mounted() {
      window.onresize = () => {
        return (() => {
          this.setDialogWidth()
        })();
      };
    },
    methods: {
      setDialogWidth() {
        let windowSize = document.body.clientWidth;
        const defaultWidth = 960;
        if (windowSize < defaultWidth) {
          this.dialogWidth = "100%";
        } else {
          this.dialogWidth = defaultWidth + "px";
        }
      },
      fetchEventAttendances(event_id) {
        api.get(`/course/${this.course.id}/attendance/${event_id}`).then(response => {
          this.eventAttendances = response.data.data;
          this.attendanceMapVisible = true;
        }).catch(error => {
          console.error('Error fetching attendances:', error);
        });
      },
      showAttendanceMap(event) {
        this.selectedEvent = event
        this.fetchEventAttendances(this.selectedEvent.id)
      },
      downloadReport() {
        api.get(`/course/${this.course.id}/attendance/report?format=csv`, {
          responseType: 'blob'
        }).then(response => {
          const blob = new Blob([response.data], { type: 'text/csv;charset=utf-8;' });
          const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
          downloadFile(blob, `${this.course.name}-attendance-${dateStr}.csv`);
        }).catch(error => {
          console.error('Error downloading attendance report:', error);
        });
      },
      getEventLocationName(locationId) {
          const location = this.locations.find(loc => loc.id === locationId);
          return location ? location.name : 'Unknown Location';
      }
    }
}
</script>

<style scoped>
.course-download-btn {
  width: 100%;
  margin: 20px 10px 10px 10px;
  text-align: left;
}

.event-card-container {
  display: flex;
  justify-content: flex-start;
  flex-wrap: wrap;
}
@media (max-width: 768px) {
  .event-card-container {
    justify-content: center;
  }
}

.event-item {
  width: 20%;
  min-width: 200px;
  margin: 10px;
  padding: 0px;
}

.attendance-map-container {
  max-width: 100px;
}
@media (max-width: 768px) {
  .attendance-map-container {
      width: 100vw !important;
  }
}
</style>
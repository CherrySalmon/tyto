<template>
  <div class="event-card-container course-card-container">
    <div class="course-content-title">Attendance Events</div>
    <div class="course-download-btn">
      <el-button color="#824533" :dark="true" @click="downloadRecord()">Download Record</el-button>
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
import axios from 'axios';
import cookieManager from '../../../lib/cookieManager';
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
          attendances: '',
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
        axios.get(`/api/course/${this.course.id}/attendance/${event_id}`, {
          headers: {
            Authorization: `Bearer ${this.account.credential}`,
          }
        }).then(response => {
          this.eventAttendances = response.data.data;
          this.attendanceMapVisible = true;
        }).catch(error => {
          console.error('Error fetching attendances:', error);
        });
      },
      fetchAttendances() {
        axios.get(`/api/course/${this.course.id}/attendance/list_all`, {
          headers: {
            Authorization: `Bearer ${this.account.credential}`,
          }
        }).then(response => {
          this.attendances = response.data.data;
          this.downloadAttendanceRecordAsCSV()
        }).catch(error => {
          console.error('Error fetching attendances:', error);
        });
      },
      showAttendanceMap(event) {
        this.selectedEvent = event
        this.fetchEventAttendances(this.selectedEvent.id)
      },
      downloadRecord() {
        this.fetchAttendances()
      },
      downloadAttendanceRecordAsCSV() {
        const eventNames = this.attendanceEvents.map(event => event.name);
        const headers = ["Student Email", "attend_sum", "attend_percent", ...eventNames];

        let csvContent = headers.join(",") + "\n";

        this.enrollments.forEach(enrollment => {
          if (enrollment.enroll_identity.includes("student")) {
            const studentEmail = enrollment.account.email;
            const attendanceDetails = {};

            // Initialize attendance details for each event with '0', absent.
            this.attendanceEvents.forEach(event => {
              attendanceDetails[event.id] = 0;
            });

            // Mark attendance as '1', present for attended events.
            this.attendances.forEach(attendance => {
              if (attendance.account_id === enrollment.account.id) {
                attendanceDetails[attendance.event_id] = 1;
              }
            });

            const attendSum = Object.values(attendanceDetails).filter(status => status === 1).length;
            const attendPercent = (attendSum / this.attendanceEvents.length) * 100;

            const rowData = [
              studentEmail,
              attendSum,
              attendPercent.toFixed(2),
              ...Object.keys(attendanceDetails).map(key => attendanceDetails[key])
            ];

            csvContent += rowData.join(",") + "\n";
          }
        });

        // Trigger download of CSV file.
        const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);

        link.setAttribute('download', `${this.course.name}-attendance-${this.getCurrentDateTimeYYYYMMDD()}.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      },
      getCurrentDateTimeYYYYMMDD() {
        const now = new Date();
        const year = now.getFullYear();
        const month = (now.getMonth() + 1).toString().padStart(2, '0');
        const day = now.getDate().toString().padStart(2, '0');
        const dateFormatted = `${year}${month}${day}`;
        return dateFormatted;
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
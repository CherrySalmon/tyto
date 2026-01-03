<template>
  <div class="single-course-container">
    <div class="page-title">{{ course.name }}</div>
    <el-row>
      <el-col :xs="24" :md="18">
          <div v-if="currentRole">
            <div class="course-content-container"
              v-if="currentRole =='owner' || currentRole =='instructor' || currentRole =='staff'">
              <div class="course-menu-bar">
                <ul class="course-menu">
                  <li class="tab" :class="$route.path.includes('attendance')?'active':''"><router-link to="attendance">Attendance Events</router-link></li>
                  <li class="tab" :class="$route.path.includes('location')?'active':''"><router-link to="location">Locations</router-link></li>
                  <li class="tab" :class="$route.path.includes('people')?'active':''"><router-link to="people">People</router-link></li>
                </ul>
              </div>
              <div class="course-manage-view">
                <RouterView
                  :course="course"
                  :attendance-events="attendanceEvents" :locations="locations" @create-event="showAttendanceEvent" @edit-event="editAttendanceEvent" @delete-event="deleteAttendanceEvent"
                  @create-location="createNewLocation" @update-location="updateLocation" @delete-location="deleteLocation"
                  :enrollments="enrollments" @new-enrolls="addEnrollments" @update-enrollment="updateEnrollment" @delete-enrollment="deleteEnrollments" :currentRole="currentRole"
                >
                </RouterView>
              </div>
            </div>
          </div>
      </el-col>

      <el-col :xs="24" :md="6">
        <div v-if="currentRole">
          <div v-if="currentRole != 'student'">
            <CourseInfoCard :course="course" :currentRole="currentRole" @show-modify-dialog="showModifyCourseDialog = true" style="margin: 20px 0;">
            </CourseInfoCard>
            <div class="selecor-role-container">
              <span style="margin: 0 10px;">View</span>
              <el-select
                v-model="selectRole"
                placeholder="Select"
                size="large"
                style="width: 100%;"
                @change="changeRole"
              >
                <el-option
                  v-for="role in selectableRoles"
                  :key="role"
                  :label="role"
                  :value="role"
                />
              </el-select>
            </div>
          </div>
        </div>
      </el-col>
    </el-row>
    <div v-if="currentRole">
      <div class="center-content" v-if="currentRole =='student'">
        <!-- <el-button type="primary" @click="changeRoute($route.params.id + '/attendance')">Mark Attendance</el-button> -->
        <CourseInfoCard :course="course" :role="currentRole" @show-modify-dialog="showModifyCourseDialog = true" style="margin: 20px 0;">
        </CourseInfoCard>
        <div class="selecor-role-container">
          <span style="margin: 0 10px;">View</span>
          <el-select
            v-model="selectRole"
            placeholder="Select"
            size="large"
            style="width: 100%;"
            @change="changeRole"
          >
            <el-option
              v-for="role in selectableRoles"
              :key="role"
              :label="role"
              :value="role"
            />
          </el-select>
        </div>
      </div>
    </div>
    <ModifyCourseDialog class="dialog-container" :courseForm="courseForm" :visible="showModifyCourseDialog"
      @dialog-closed="showModifyCourseDialog = false" @update-course="updateCourse"></ModifyCourseDialog>

    <CreateAttendanceEventDialog class="dialog-container" :visible="showCreateAttendanceEventDialog" :locations="locations"
      @dialog-closed="showCreateAttendanceEventDialog = false" @create-event="createAttendanceEvent">
    </CreateAttendanceEventDialog>

    <template v-if="showModifyAttendanceEventDialog">
      <ModifyAttendanceEventDialog class="dialog-container" :eventForm="createAttendanceEventForm" :visible="showModifyAttendanceEventDialog"
        :locations="locations" @dialog-closed="showModifyAttendanceEventDialog = false"
        @update-event="updateAttendanceEvent">
      </ModifyAttendanceEventDialog>
    </template>
  </div>
</template>

<script>
import axios from 'axios';
import cookieManager from '../../lib/cookieManager';
import CourseInfoCard from './components/CourseInfoCard.vue';
import ModifyCourseDialog from './components/ModifyCourseDialog.vue';
import ManagePeopleCard from './components/ManagePeopleCard.vue';
import CreateAttendanceEventDialog from './components/CreateAttendanceEventDialog.vue';
import ModifyAttendanceEventDialog from './components/ModifyAttendanceEventDialog.vue'
import AttendanceEventCard from './components/AttendanceEventCard.vue';
import LocationCard from './components/LocationCard.vue'
import { ElMessage } from 'element-plus'

export default {
  name: 'SingleCourse',
  components: { CourseInfoCard, ModifyCourseDialog, ManagePeopleCard, CreateAttendanceEventDialog, AttendanceEventCard, ModifyAttendanceEventDialog, LocationCard },
  data() {
    return {
      course: {
      },
      courseForm: {
      },
      attendanceEventForm: {},
      createAttendanceEventForm: {
        name: '',
        location_id: '',
        start_at: '',
        end_at: '',
      },
      attendanceEvents: [],
      locations: [],
      optionLocation: '',
      account: {
        roles: [],
        credential: ''
      },
      selectableRoles: [],
      currentRole: '',
      selectRole: '',
      showModifyCourseDialog: false,
      showCreateAttendanceEventDialog: false,
      showModifyAttendanceEventDialog: false,
      isAddedValue: false,
      enrollments: [],
      currentEventID: '',
      activeTab: 'events'
    };
  },
  computed: {
    tabStyle() {
      if (window.innerWidth < 992) {
        return "top"
      }
      return "left"
    }
  },
  created() {
    this.course.id = this.$route.params.id;
    this.account = cookieManager.getAccount()
    if (this.account) {
      this.fetchCourse(this.course.id);
    }
  },
  watch: {
    currentRole(newRole) {
      if(newRole == 'owner' || newRole == 'instructor' || newRole == 'staff') {
        this.fetchAttendanceEvents(this.course.id);
        this.fetchLocations();
        this.fetchEnrollments();
      }
    }
  },
  methods: {
    changeRole(role) {
      ElMessageBox.confirm(
        'page will change to '+role+' view. Continue?',
        'Warning',
        {
          confirmButtonText: 'OK',
          cancelButtonText: 'Cancel',
          type: 'warning',
        }
      )
        .then(() => {
          this.currentRole = role
          ElMessage({
            type: 'success',
            message: 'Change to '+role+' view',
          })
        })
        .catch(() => {
          this.selectRole = this.currentRole
          ElMessage({
            type: 'info',
            message: 'Change canceled',
          })
        })
    },
    changeTab(tab_name) {
      if (tab_name == 'people') {
        this.fetchEnrollments()
      }
    },
    changeRoute(route) {
      this.$router.push({ path: route })
    },
    fetchCourse(id) {
      axios.get(`/api/course/${id}`, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        },
      }).then(response => {
        this.course = response.data.data;
        // Copying the course object to courseForm
        let course = {...this.course}
        course.start_at = new Date(course.start_at)
        course.end_at = new Date(course.end_at)
        this.courseForm = course
        this.selectableRoles = this.course.enroll_identity
        this.selectRole = this.selectableRoles[0]
        this.currentRole = this.selectRole
        // Deleting the id and enroll_identity keys from courseForm
        delete this.courseForm.id;
        delete this.courseForm.enroll_identity;
      }).catch(error => {
        console.error('Error fetching course:', error);
      });
    },
    updateCourse(form) {
      this.courseForm = form
      if (this.courseForm.repeat == 'no-repeat') {
        this.courseForm.occurrence = 1
      }
      axios.put('/api/course/' + this.course.id, this.courseForm, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        },
      }).then(() => {
        this.showModifyCourseDialog = false;
        this.fetchCourse(this.course.id);
      }).catch(error => {
        console.error('Error creating course:', error);
      });
    },
    fetchEnrollments() {
      axios.get(`/api/course/${this.course.id}/enroll`, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        }
      }).then(response => {
        this.enrollments = response.data.data;
        this.enrollments.forEach((enrollment) => {
          enrollment.enrolls = response.data.data.enroll_identity
        });

      }).catch(error => {
        console.error('Error fetching enrollments:', error);
      });
    },

    addEnrollments(newEnrolls) {
      axios.post(`/api/course/${this.course.id}/enroll`, { enroll: newEnrolls }, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        }
      }).then(response => {
        this.fetchEnrollments()
      }).catch(error => {
        console.error('Error fetching enrollments:', error);
        ElMessage.error(error.message)
      });
    },

    updateEnrollment(enrollment) {
      let entollList = {
        enroll: {
          email: enrollment.account.email,
          roles: enrollment.enroll_identity.join(',')
        }
      }
      axios.post(`/api/course/${this.course.id}/enroll/${enrollment.account.id}`, entollList, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        }
      }).then(response => {
        this.fetchEnrollments()
      }).catch(error => {
        console.error('Error fetching enrollments:', error);
        ElMessage.error(error.message)
      });
    },

    deleteEnrollments(enrollment) {
      axios.delete(`/api/course/${this.course.id}/enroll/${enrollment}`, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        }
      }).then(response => {
        this.fetchEnrollments()
      }).catch(error => {
        console.error('Error fetching enrollments:', error);
      });
    },
    createAttendanceEvent(eventForm) {
      axios.post(`/api/course/${this.course.id}/event`, eventForm, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        },
      }).then(() => {
        this.showCreateAttendanceEventDialog = false
        this.createAttendanceEventForm = {}
        this.fetchAttendanceEvents() // Refresh the list after adding
      }).catch(error => {
        console.error('Error creating attendance event:', error);
      });
    },
    fetchAttendanceEvents() {
      axios.get(`/api/course/${this.course.id}/event`, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        },
      }).then(response => {
        let attendanceEvents = response.data.data;
        this.attendanceEvents = attendanceEvents
      }).catch(error => {
        console.error('Error fetching attendance events:', error);
      });
    },
    fetchLocations() {
      axios.get(`/api/course/${this.course.id}/location`, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        },
      }).then(response => {
        this.locations = response.data.data
      }).catch(error => {
        console.error('Error fetching locations:', error);
      });
    },
    createNewLocation(locationData) {
      let courseId = this.$route.params.id;
      axios.post(`/api/course/${courseId}/location`, locationData, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        }
      })
        .then(response => {
          // alert('Location created successfully', response);
          ElMessage({
            type: 'success',
            message: 'Location created successfully'
          })
          this.fetchLocations();
        })
        .catch(error => {
          console.error('Error creating location', error);
          ElMessage({
            type: 'error',
            message: 'Error creating location'
          })
        });
    },
    updateLocation(id, locationData) {
      let courseId = this.$route.params.id;
      axios.put(`/api/course/${courseId}/location/${id}`, locationData, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        }
      })
        .then(response => {
          ElMessage({
            type: 'success',
            message: 'Location updated successfully'
          })
          this.fetchLocations();
        })
        .catch(error => {
          console.error('Error updating location', error);
          ElMessage({
            type: 'error',
            message: error,
          })
        });
    },
    deleteLocation(locationId) {
      axios.delete(`/api/course/${this.course.id}/location/${locationId}`, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        }
      }).then(() => {
        console.log(`Location ${locationId} deleted successfully.`);
        // Refresh the locations list
        this.fetchLocations();
      }).catch(error => {
        console.error('Error deleting location:', error.message);
        ElMessage({
            type: 'error',
            message: error,
          })
      });
    },
    deleteAttendanceEvent(eventId) {
      axios.delete(`/api/course/${this.course.id}/event/${eventId}`, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        }
      }).then(() => {
        console.log(`Event ${eventId} deleted successfully.`);
        // Refresh the attendance events list
        this.fetchAttendanceEvents(this.course.id);
      }).catch(error => {
        console.error('Error deleting attendance event:', error);
      });
    },
    showAttendanceEvent() {
      this.createAttendanceEventForm = {}
      this.showCreateAttendanceEventDialog = true
    },
    editAttendanceEvent(eventId) {
      const event = this.attendanceEvents.find(e => e.id === eventId);
      if (event) {
        // this.attendanceEventForm = {...event}
        this.attendanceEventForm = {
          "course_id": this.course.id,
          "location_id": event.location_id,
          "name": event.name,
          "start_at": event.start_at,
          "end_at": event.end_at
        };
        delete this.attendanceEventForm.id;
        this.showModifyAttendanceEventDialog = true;
        this.createAttendanceEventForm = this.attendanceEventForm;
        this.currentEventID = eventId;
      } else {
        console.error('Event not found!');
      }
    },

    updateAttendanceEvent() {
      axios.put(`/api/course/${this.course.id}/event/${this.currentEventID}`, this.attendanceEventForm, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        },
      }).then(() => {
        this.showModifyAttendanceEventDialog = false;
        this.fetchAttendanceEvents(); // Refresh the list after adding
      }).catch(error => {
        console.error('Error modifying attendance event:', error);
      });
    },
    onConfirm() {
      if (this.optionLocation) {
        this.locations.push({
          label: this.optionLocation,
          value: this.optionLocation,
        })
        this.clear()
      }
    },
    clear() {
      this.optionLocation = ''
      this.isAddedValue = false
    }
  },
};
</script>

<style>
.single-course-container {
  max-width: 1680px;
  margin: auto;
  width: 95%;
  padding: 15px 30px;
}
/* share class for children cand*/
.course-content-title {
  font-size: 1.5rem;
  text-align: left;
  padding: 0px 20px;
  width: 100%;
}
.course-card-container {
  margin: 20px 20px;
}
@media (max-width: 768px) {
  .course-card-container {
    margin: 10px 0 !important;
  }
}
/* end of common class */
.course-content-container {
  display: flex;
  flex-wrap: wrap;
}
.course-manage-view {
  width: 80%;
}
.course-menu-bar {
  width: 20%;
}
.course-menu {
  list-style-type: none;
  margin: 0;
  padding: 0;
}

.course-menu .tab a {
  display: block;
  text-align: center;
  text-decoration: none;
  margin: 5px 0;
  padding: 10px 10px;
  font-size: 1rem;
  font-weight: 800;
  border-radius: 5px;
  color: #333;
  transition: background-color 0.3s;
  width: 90%;
}

.course-menu .tab a:hover {
  color: #EAA034;
  background-color: #ebebeb;
}

.active a {
  color: #EAA034 !important;
}

@media (max-width: 768px) {
  .course-manage-view {
    width: 100%;
  }
  .course-menu-bar {
    width: 100%;
  }
  .course-menu .tab {
    flex-basis: 100%;
    margin-bottom: 5px;
    width: 100%;
  }
  .course-menu .tab a {
    width: 100%;
  }
  .single-course-container {
    width: 100%;
    padding: 0px;
  }
}

.event-item {
  border-bottom: 1px solid #eee;
  text-align: center;
  padding: 10px 5px;
  width: 200px;
  margin: 20px;
  cursor: pointer;
  display: inline-block;
  font-size: 14px;
  line-height: 2.5rem;
}

.option-input {
  width: 90%;
  margin-bottom: 8px;
  margin-left: 5%;
}

.box-card {
  text-align: left;
  line-height: 2rem;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.center-content {
  margin: auto;
  width: 50%;
  min-width: 280px;
}
.selecor-role-container {
  justify-content: space-between;
  display: flex;
  line-height: 40px;
}

.dialog-container {
  width: 600px !important;
}
@media (max-width: 768px) {
  .dialog-container {
      width: 100% !important;
  }
}
</style>

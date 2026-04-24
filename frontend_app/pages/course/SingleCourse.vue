<template>
  <div class="single-course-container">
    <div class="page-title">{{ course.name }}</div>
    <el-row>
      <el-col :xs="24" :md="18">
          <div v-if="currentRole">
            <div class="course-content-container"
              v-if="course.policies && course.policies.can_update">
              <div class="course-menu-bar">
                <ul class="course-menu">
                  <li class="tab" :class="$route.path.includes('attendance')?'active':''"><router-link to="attendance">Attendance Events</router-link></li>
                  <li class="tab" :class="$route.path.includes('location')?'active':''"><router-link to="location">Locations</router-link></li>
                  <li class="tab" :class="$route.path.includes('people')?'active':''"><router-link to="people">People</router-link></li>
                  <li class="tab" :class="$route.path.includes('assignments')?'active':''"><router-link to="assignments">Assignments</router-link></li>
                </ul>
              </div>
              <div class="course-manage-view">
                <RouterView
                  :course="course"
                  :attendance-events="attendanceEvents" :locations="locations" @create-event="showAttendanceEvent" @edit-event="editAttendanceEvent" @delete-event="deleteAttendanceEvent"
                  @create-location="createNewLocation" @update-location="updateLocation" @delete-location="deleteLocation"
                  :enrollments="enrollments" :assignableRoles="assignableRoles" @new-enrolls="addEnrollments" @update-enrollment="updateEnrollment" @delete-enrollment="deleteEnrollments" :currentRole="currentRole"
                  :assignments="assignments" :canManage="true" @create-assignment="showCreateAssignment" @edit-assignment="editAssignment" @delete-assignment="deleteAssignment" @publish-assignment="publishAssignment" @unpublish-assignment="unpublishAssignment" @view-assignment="viewAssignment"
                >
                </RouterView>
              </div>
            </div>
          </div>
      </el-col>

      <el-col :xs="24" :md="6">
        <div v-if="currentRole">
          <div v-if="course.policies && course.policies.can_update">
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
      <div v-if="course.policies && !course.policies.can_update">
        <el-row>
          <el-col :xs="24" :md="18">
            <div class="course-content-container">
              <div class="course-menu-bar">
                <ul class="course-menu">
                  <li class="tab" :class="$route.path.includes('assignments')?'active':''"><router-link to="assignments">Assignments</router-link></li>
                </ul>
              </div>
              <div class="course-manage-view">
                <RouterView
                  :course="course"
                  :assignments="assignments"
                  :canManage="false"
                  @view-assignment="viewAssignment"
                >
                </RouterView>
              </div>
            </div>
          </el-col>
          <el-col :xs="24" :md="6">
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
          </el-col>
        </el-row>
      </div>
    </div>
    <ModifyCourseDialog class="dialog-container" :courseForm="courseForm" :visible="showModifyCourseDialog"
      @dialog-closed="showModifyCourseDialog = false" @update-course="updateCourse"></ModifyCourseDialog>

    <CreateEventsDialog :visible="showCreateAttendanceEventDialog" :locations="locations"
      :existing-event-dates="existingEventDates" :submitting="submittingEvents" :row-errors="eventRowErrors"
      :course-start-at="course.start_at" :course-end-at="course.end_at"
      @dialog-closed="showCreateAttendanceEventDialog = false" @create-events="createAttendanceEvents">
    </CreateEventsDialog>

    <template v-if="showModifyAttendanceEventDialog">
      <ModifyAttendanceEventDialog class="dialog-container" :eventForm="createAttendanceEventForm" :visible="showModifyAttendanceEventDialog"
        :locations="locations" @dialog-closed="showModifyAttendanceEventDialog = false"
        @update-event="updateAttendanceEvent">
      </ModifyAttendanceEventDialog>
    </template>

    <CreateAssignmentDialog class="dialog-container" :visible="showCreateAssignmentDialog" :attendanceEvents="attendanceEvents"
      @dialog-closed="showCreateAssignmentDialog = false" @create-assignment="createAssignment">
    </CreateAssignmentDialog>

    <template v-if="showModifyAssignmentDialog">
      <ModifyAssignmentDialog class="dialog-container" :assignmentForm="assignmentForm" :assignmentStatus="currentAssignmentStatus"
        :visible="showModifyAssignmentDialog"
        :attendanceEvents="attendanceEvents" @dialog-closed="showModifyAssignmentDialog = false"
        @update-assignment="updateAssignment">
      </ModifyAssignmentDialog>
    </template>

    <AssignmentDetailDialog :assignment="currentAssignment" :visible="showAssignmentDetailDialog"
      :attendanceEvents="attendanceEvents" :submissions="currentSubmissions" :submissionLoading="submissionLoading"
      @dialog-closed="closeAssignmentDetail" @create-submission="createSubmission">
    </AssignmentDetailDialog>
  </div>
</template>

<script>
import api from '@/lib/tytoApi';
import session from '../../lib/session';
import CourseInfoCard from './components/CourseInfoCard.vue';
import ModifyCourseDialog from './components/ModifyCourseDialog.vue';
import ManagePeopleCard from './components/ManagePeopleCard.vue';
import CreateEventsDialog from './components/CreateEventsDialog.vue';
import ModifyAttendanceEventDialog from './components/ModifyAttendanceEventDialog.vue'
import AttendanceEventCard from './components/AttendanceEventCard.vue';
import LocationCard from './components/LocationCard.vue'
import CreateAssignmentDialog from './components/CreateAssignmentDialog.vue';
import ModifyAssignmentDialog from './components/ModifyAssignmentDialog.vue';
import AssignmentDetailDialog from './components/AssignmentDetailDialog.vue';
import { ElMessage } from 'element-plus'

export default {
  name: 'SingleCourse',
  components: { CourseInfoCard, ModifyCourseDialog, ManagePeopleCard, CreateEventsDialog, AttendanceEventCard, ModifyAttendanceEventDialog, LocationCard, CreateAssignmentDialog, ModifyAssignmentDialog, AssignmentDetailDialog },
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
      submittingEvents: false,
      eventRowErrors: {},
      isAddedValue: false,
      enrollments: [],
      assignableRoles: [],
      currentEventID: '',
      activeTab: 'events',
      assignments: [],
      showCreateAssignmentDialog: false,
      showModifyAssignmentDialog: false,
      showAssignmentDetailDialog: false,
      currentAssignment: {},
      currentAssignmentId: '',
      currentAssignmentStatus: 'draft',
      assignmentForm: {},
      currentSubmissions: [],
      submissionLoading: false
    };
  },
  computed: {
    tabStyle() {
      if (window.innerWidth < 992) {
        return "top"
      }
      return "left"
    },
    existingEventDates() {
      const pad2 = n => String(n).padStart(2, '0')
      return (this.attendanceEvents || []).map(e => {
        const d = new Date(e.start_at)
        if (isNaN(d.getTime())) return null
        return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
      }).filter(Boolean)
    }
  },
  created() {
    this.course.id = this.$route.params.id;
    this.account = session.getAccount()
    if (this.account) {
      this.fetchCourse(this.course.id);
    }
  },
  watch: {
    currentRole() {
      if(this.course.policies && this.course.policies.can_update) {
        this.fetchAttendanceEvents(this.course.id);
        this.fetchLocations();
        this.fetchEnrollments();
        this.fetchAssignableRoles();
      }
      this.fetchAssignments();
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
      api.get(`/course/${id}`).then(response => {
        this.course = response.data.data;
        // Copying the course object to courseForm
        let course = {...this.course}
        course.start_at = new Date(course.start_at)
        course.end_at = new Date(course.end_at)
        this.courseForm = course
        this.selectableRoles = this.course.enroll_identity
        this.selectRole = this.selectableRoles[0]
        this.currentRole = this.selectRole
        // Deleting non-form keys from courseForm
        delete this.courseForm.id;
        delete this.courseForm.enroll_identity;
        delete this.courseForm.policies;
      }).catch(error => {
        console.error('Error fetching course:', error);
      });
    },
    updateCourse(form) {
      this.courseForm = form
      if (this.courseForm.repeat == 'no-repeat') {
        this.courseForm.occurrence = 1
      }
      api.put('/course/' + this.course.id, this.courseForm).then(() => {
        this.showModifyCourseDialog = false;
        this.fetchCourse(this.course.id);
      }).catch(error => {
        console.error('Error creating course:', error);
      });
    },
    fetchAssignableRoles() {
      api.get(`/course/${this.course.id}/assignable_roles`).then(response => {
        this.assignableRoles = response.data.data;
      }).catch(error => {
        console.error('Error fetching assignable roles:', error);
      });
    },
    fetchEnrollments() {
      api.get(`/course/${this.course.id}/enroll`).then(response => {
        this.enrollments = response.data.data;
        this.enrollments.forEach((enrollment) => {
          enrollment.enrolls = response.data.data.enroll_identity
        });

      }).catch(error => {
        console.error('Error fetching enrollments:', error);
      });
    },

    addEnrollments(newEnrolls) {
      api.post(`/course/${this.course.id}/enroll`, { enroll: newEnrolls }).then(response => {
        this.fetchEnrollments()
      }).catch(error => {
        console.error('Error fetching enrollments:', error);
      });
    },

    updateEnrollment(enrollment) {
      let entollList = {
        enroll: {
          email: enrollment.account.email,
          roles: enrollment.enroll_identity.join(',')
        }
      }
      api.post(`/course/${this.course.id}/enroll/${enrollment.account.id}`, entollList).then(response => {
        this.fetchEnrollments()
      }).catch(error => {
        console.error('Error fetching enrollments:', error);
      });
    },

    deleteEnrollments(enrollment) {
      api.delete(`/course/${this.course.id}/enroll/${enrollment}`).then(response => {
        this.fetchEnrollments()
      }).catch(error => {
        console.error('Error fetching enrollments:', error);
      });
    },
    createAttendanceEvents({ events, rowIds }) {
      this.submittingEvents = true
      this.eventRowErrors = {}
      api.post(`/course/${this.course.id}/events`, { events })
        .then((response) => {
          const count = events.length
          ElMessage({ type: 'success', message: `Created ${count} event${count === 1 ? '' : 's'}` })
          this.showCreateAttendanceEventDialog = false
          this.fetchAttendanceEvents()
        })
        .catch(error => {
          console.error('Error creating attendance events:', error)
          const data = error?.response?.data || {}
          const errorsByIndex = data.errors_by_row || data.row_errors || null
          if (errorsByIndex && rowIds) {
            const mapped = {}
            Object.entries(errorsByIndex).forEach(([idx, msg]) => {
              const id = rowIds[parseInt(idx, 10)]
              if (id) mapped[id] = msg
            })
            this.eventRowErrors = mapped
            ElMessage({ type: 'error', message: 'Some rows failed — see highlighted errors' })
          } else {
            ElMessage({ type: 'error', message: data.details || data.message || 'Failed to create events' })
          }
        })
        .finally(() => {
          this.submittingEvents = false
        })
    },
    fetchAttendanceEvents() {
      api.get(`/course/${this.course.id}/events`).then(response => {
        let attendanceEvents = response.data.data;
        this.attendanceEvents = attendanceEvents
      }).catch(error => {
        console.error('Error fetching attendance events:', error);
      });
    },
    fetchLocations() {
      api.get(`/course/${this.course.id}/location`).then(response => {
        this.locations = response.data.data
      }).catch(error => {
        console.error('Error fetching locations:', error);
      });
    },
    createNewLocation(locationData) {
      let courseId = this.$route.params.id;
      api.post(`/course/${courseId}/location`, locationData)
        .then(response => {
          ElMessage({
            type: 'success',
            message: 'Location created successfully'
          })
          this.fetchLocations();
        })
        .catch(error => {
          console.error('Error creating location', error);
        });
    },
    updateLocation(id, locationData) {
      let courseId = this.$route.params.id;
      api.put(`/course/${courseId}/location/${id}`, locationData)
        .then(response => {
          ElMessage({
            type: 'success',
            message: 'Location updated successfully'
          })
          this.fetchLocations();
        })
        .catch(error => {
          console.error('Error updating location', error);
        });
    },
    deleteLocation(locationId) {
      api.delete(`/course/${this.course.id}/location/${locationId}`).then(() => {
        console.log(`Location ${locationId} deleted successfully.`);
        // Refresh the locations list
        this.fetchLocations();
      }).catch(error => {
        console.error('Error deleting location:', error.message);
      });
    },
    deleteAttendanceEvent(eventId) {
      api.delete(`/course/${this.course.id}/events/${eventId}`).then(() => {
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
      api.put(`/course/${this.course.id}/events/${this.currentEventID}`, this.attendanceEventForm).then(() => {
        this.showModifyAttendanceEventDialog = false;
        this.fetchAttendanceEvents(); // Refresh the list after adding
      }).catch(error => {
        console.error('Error modifying attendance event:', error);
      });
    },
    fetchAssignments() {
      api.get(`/course/${this.course.id}/assignments`).then(response => {
        this.assignments = response.data.data;
      }).catch(error => {
        console.error('Error fetching assignments:', error);
      });
    },
    showCreateAssignment() {
      this.showCreateAssignmentDialog = true;
    },
    createAssignment(form) {
      api.post(`/course/${this.course.id}/assignments`, form).then(() => {
        this.showCreateAssignmentDialog = false;
        this.fetchAssignments();
        ElMessage({ type: 'success', message: 'Assignment created' });
      }).catch(error => {
        console.error('Error creating assignment:', error);
      });
    },
    editAssignment(assignmentId) {
      api.get(`/course/${this.course.id}/assignments/${assignmentId}`).then(response => {
        const assignment = response.data.data;
        this.assignmentForm = {
          title: assignment.title,
          description: assignment.description,
          due_at: assignment.due_at,
          event_id: assignment.event_id,
          allow_late_resubmit: assignment.allow_late_resubmit,
          submission_requirements: assignment.submission_requirements || []
        };
        this.currentAssignmentId = assignmentId;
        this.currentAssignmentStatus = assignment.status;
        this.showModifyAssignmentDialog = true;
      }).catch(error => {
        console.error('Error fetching assignment for edit:', error);
      });
    },
    updateAssignment(form) {
      api.put(`/course/${this.course.id}/assignments/${this.currentAssignmentId}`, form).then(() => {
        this.showModifyAssignmentDialog = false;
        this.fetchAssignments();
        ElMessage({ type: 'success', message: 'Assignment updated' });
      }).catch(error => {
        console.error('Error updating assignment:', error);
      });
    },
    deleteAssignment(assignmentId) {
      ElMessageBox.confirm(
        'Are you sure you want to delete this assignment?',
        'Delete Assignment',
        { confirmButtonText: 'Delete', cancelButtonText: 'Cancel', type: 'warning' }
      ).then(() => {
        api.delete(`/course/${this.course.id}/assignments/${assignmentId}`).then(() => {
          this.fetchAssignments();
          ElMessage({ type: 'success', message: 'Assignment deleted' });
        }).catch(error => {
          console.error('Error deleting assignment:', error);
        });
      }).catch(() => {});
    },
    publishAssignment(assignmentId) {
      ElMessageBox.confirm(
        'Publishing makes this assignment visible to students. Submission requirements (e.g., files, URLs to upload) cannot be modified while published — unpublish first to make changes. Continue?',
        'Publish Assignment',
        { confirmButtonText: 'Publish', cancelButtonText: 'Cancel', type: 'warning' }
      ).then(() => {
        api.post(`/course/${this.course.id}/assignments/${assignmentId}/publish`).then(() => {
          this.fetchAssignments();
          ElMessage({ type: 'success', message: 'Assignment published' });
        }).catch(error => {
          console.error('Error publishing assignment:', error);
        });
      }).catch(() => {});
    },
    unpublishAssignment(assignmentId) {
      ElMessageBox.confirm(
        'This will return the assignment to draft status and hide it from students. You can then edit requirements before republishing. Continue?',
        'Unpublish Assignment',
        { confirmButtonText: 'Unpublish', cancelButtonText: 'Cancel', type: 'warning' }
      ).then(() => {
        api.post(`/course/${this.course.id}/assignments/${assignmentId}/unpublish`).then(() => {
          this.fetchAssignments();
          ElMessage({ type: 'success', message: 'Assignment unpublished' });
        }).catch(error => {
          console.error('Error unpublishing assignment:', error);
        });
      }).catch(() => {});
    },
    viewAssignment(assignmentId) {
      api.get(`/course/${this.course.id}/assignments/${assignmentId}`).then(response => {
        this.currentAssignment = response.data.data;
        this.showAssignmentDetailDialog = true;
        this.fetchSubmissions(assignmentId);
      }).catch(error => {
        console.error('Error fetching assignment:', error);
      });
    },
    fetchSubmissions(assignmentId) {
      this.submissionLoading = true;
      api.get(`/course/${this.course.id}/assignments/${assignmentId}/submissions`).then(response => {
        this.currentSubmissions = response.data.data;
      }).catch(error => {
        console.error('Error fetching submissions:', error);
        this.currentSubmissions = [];
      }).finally(() => {
        this.submissionLoading = false;
      });
    },
    createSubmission(assignmentId, entries) {
      api.post(`/course/${this.course.id}/assignments/${assignmentId}/submissions`, { entries }).then(response => {
        ElMessage({ type: 'success', message: 'Submission saved' });
        this.fetchSubmissions(assignmentId);
      }).catch(error => {
        const msg = error.response?.data?.message || 'Error submitting';
        ElMessage({ type: 'error', message: msg });
        console.error('Error creating submission:', error);
      });
    },
    closeAssignmentDetail() {
      this.showAssignmentDetailDialog = false;
      this.currentSubmissions = [];
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

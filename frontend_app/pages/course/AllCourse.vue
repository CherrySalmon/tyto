<template>
  <div>
    <div style="margin: 40px">
      <h2>Welcome Back, {{account.name}}!</h2>
      <p>You have access to {{ getFeatures(account.roles) }}!</p>
    </div>
    <div v-if="events.length > 0">
      <div class="page-title">Events</div>
      <div class="course-container">
        <el-card v-for="event in events" :key="event.id" class="course-item" shadow="hover">
              <div slot="header" class="clearfix">
              <span>{{ event.name }}</span>
              </div><br />
              <div>
                  <p>Course: {{  event.course_name || 'N/A' }}</p>
                  <p>Location: {{ event.location_name || 'N/A' }}</p>
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
    <div class="page-title">Courses</div>
    <template v-if="account">
      <el-button v-if="account.roles.includes('creator')" @click="showCreateCourseDialog = true" color="#824533"
        :dark="true">Start a New Course</el-button>
    </template>
    <el-dialog title="Create Course" v-model="showCreateCourseDialog" width="100%" style="max-width: 600px;">
      <el-form ref="createCourseForm" :model="createCourseForm" label-width="auto" :rules="rules" :status-icon="true">
        <el-form-item label="Name" prop="name">
          <el-input v-model="createCourseForm.name" style="width:100%;"></el-input>
        </el-form-item>
        <el-form-item label="Start Time">
          <el-date-picker v-model="createCourseForm.start_at" type="datetime"
            placeholder="Select start time" time-format="HH:mm" style="width:100%;"></el-date-picker>
        </el-form-item>
        <el-form-item label="End Time">
          <el-date-picker v-model="createCourseForm.end_at" type="datetime"
            placeholder="Select end time" time-format="HH:mm" style="width:100%;"></el-date-picker>
        </el-form-item>
        <el-form-item label="Logo">
          <el-input v-model="createCourseForm.logo" style="width:100%;"></el-input>
        </el-form-item>
      </el-form>
      <span slot="footer" class="dialog-footer">
        <el-button @click="closeForm('createCourseForm')">Cancel</el-button>
        <el-button type="primary" @click="submitForm('createCourseForm')">Confirm</el-button>
      </span>
    </el-dialog>

    <div class="course-container">
      <template v-for="course in courses" :key="course.id">
        <el-card class="course-item" shadow="hover">
          <div @click="changeRoute('/course/' + course.id + '/attendance')">
            <img :src="course.icon" class="image" />
            <div style="padding: 14px">
              <h3>{{ course.name }}</h3>
            </div>
          </div>
          <el-popconfirm v-if="account.roles.includes('creator')" title="Are you sure to delete this?" @confirm="deleteCourse(course.id)">
            <template #reference>
              <div class="course-option-container">
                <el-icon><Delete /></el-icon>
              </div><el-button>Delete</el-button>
            </template>
          </el-popconfirm>
          
        </el-card>
      </template>
    </div>
  </div>
</template>
  
<script>
import axios from 'axios';
import cookieManager from '../../lib/cookieManager';
import { ElNotification } from 'element-plus'

export default {
  name: 'Courses',

  data() {
    return {
      rules: {
        name: [
          { required: true, message: 'Please input course name', trigger: 'blur' }
        ]
      },
      features: {
        admin: 'manage accounts',
        creator: 'create courses',
        member: 'mark attendance'
      },
      courses: [],
      account: {
        roles: [],
        credential: ''
      },
      showCreateCourseDialog: false,
      createCourseForm: {
        name: '',
        start_at: '',
        end_at: '',
        logo: '',
      },
      events: {},
    };
  },
  created() {
    this.accountCredential = cookieManager.getCookie('account_credential');
    this.account = cookieManager.getAccount()
    if (this.account) {
      this.fetchCourses()
      this.fetchEventData()
    }
  },
  methods: {
    async fetchEventData() { // Mark the method as async
        try {
            const response = await axios.get(`/api/current_event/`, {
                headers: {
                    Authorization: `Bearer ${this.accountCredential}`,
                },
            });

            this.events = await Promise.all(response.data.data.map(async (event) => {
                // Use getCourseName to fetch the course name asynchronously
                let course_name = await this.getCourseName(event.course_id)
                let location_name = await this.getLocationName(event)
                let isAttendanceExisted = await this.findAttendance(event)
                return {
                    ...event,
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
            console.log('Event Data Fetched Successfully:', response.data.data);
            this.location = response.data.data;
            this.isEventDataFetched = true;

            let range = 0.0005
            const minLat = this.location.latitude - range;
            const maxLat = this.location.latitude + range;
            const minLng = this.location.longitude - range
            const maxLng = this.location.longitude + range;

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
            // Vue 2 reactivity caveat workaround
            // this.$set(this.events[eventIndex], 'isAttendanceExisted', status);
            // For Vue 3, you can directly assign the value:
            this.events[eventIndex].isAttendanceExisted = status;
        }
    },
    getFeatures(roles) {
      let features = roles.map((role) => {
        return this.features[role]
      })
      return features.join(', ')
    },
    changeRoute(route) {
      this.$router.push(route)
    },
    deleteCourse(course_id) {
      axios.delete('api/course/'+course_id, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        },
      }).then(response => {
        ElNotification({
          title: 'Success',
          message: 'Delete success!',
          type: 'success',
        })
        this.fetchCourses()
      }).catch(error => {
        console.error('Error fetching courses:', error);
        ElNotification({
          title: 'Error',
          message: error.message,
          type: 'error',
        })
      });
    },
    fetchCourses() {
      axios.get('api/course', {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        },
      }).then(response => {
        this.courses = response.data.data;
      }).catch(error => {
        console.error('Error fetching courses:', error);
      });
    },
    submitForm(formName) {
      this.$refs[formName].validate((valid) => {
        if (valid) {
          this.createCourse()
        } else {
          return false;
        }
      });
    },
    resetForm(formName) {
      this.$refs[formName].resetFields();
    },
    closeForm(formName) {
      this.$refs[formName].resetFields();
      this.showCreateCourseDialog = false;
    },
    createCourse() {
      axios.post('api/course', this.createCourseForm, {
        headers: {
          Authorization: `Bearer ${this.account.credential}`,
        },
      }).then(() => {
        this.showCreateCourseDialog = false;
        this.fetchCourses();
      }).catch(error => {
        console.error('Error creating course:', error);
      });
    },
  },
};
</script>


<style scoped>
p {
  margin-top: 12px;
}

.course-item {
  border-bottom: 1px solid #eee;
  padding: 20px 0;
  width: 270px;
  margin: 20px;
  cursor: pointer;
}

.course-container {
  display: flex;
  justify-content: left;
  width: 90%;
  margin: 1% auto;
  flex-wrap: wrap;
}

@media screen and (max-width: 640px) {
  .course-container {
    justify-content: center;
  }
}

.course-option-container {
  background-color: #f56c6c;
  width: 35px;
  height: 35px;
  color: #fff;
  padding: 9px 10px;
  border-radius: 50%;
  cursor: pointer;
  float: right;
}
</style>
  
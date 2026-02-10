<template>
  <div>
    <div style="margin: 40px">
      <h2>Welcome Back, {{account.name}}!</h2>
      <p>You have access to {{ describeRoles(account.roles) }}!</p>
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
import api from '@/lib/tyto-api';
import cookieManager from '../../lib/cookie-manager';
import { recordAttendance } from '../../lib/attendance-manager';
import { describeRoles } from '../../lib/roles';
import { ElNotification, ElMessageBox, ElLoading } from 'element-plus'

export default {
  name: 'Courses',

  data() {
    return {
      rules: {
        name: [
          { required: true, message: 'Please input course name', trigger: 'blur' }
        ]
      },
      courses: [],
      account: {
        roles: [],
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
    this.account = cookieManager.getAccount()
    if (this.account) {
      this.fetchCourses()
      this.fetchEventData()
    }
  },
  methods: {
    describeRoles,
    async fetchEventData() {
        try {
            const response = await api.get('/current_event/');

            this.events = response.data.data.map(event => ({
                ...event,
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
    },
    changeRoute(route) {
      this.$router.push(route)
    },
    deleteCourse(course_id) {
      api.delete('/course/'+course_id).then(response => {
        ElNotification({
          title: 'Success',
          message: 'Delete success!',
          type: 'success',
        })
        this.fetchCourses()
      }).catch(error => {
        console.error('Error deleting course:', error);
      });
    },
    fetchCourses() {
      api.get('/course').then(response => {
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
      api.post('/course', this.createCourseForm).then(() => {
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
  
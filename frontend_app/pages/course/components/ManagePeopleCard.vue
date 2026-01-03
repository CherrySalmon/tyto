<template>
  <div class="course-card-container">
    <div class="course-content-title">People</div>
    <h1 class="people-title">Add new student</h1>
    <div class="input-email-container">
      <div style="width:100%;">
        <el-steps :active="enrollStep">
          <el-step title="Step 1" />
          <el-step title="Step 2" />
        </el-steps>
      </div>
      <div v-if="enrollStep == 1" class="input-email-item">
        <el-input v-model="newEnrollmentEmails" placeholder="Enter email addresses (space-separated)"
          style="width: 100%;height: 40px;margin: 10px 0;" @keyup.enter="handleEmailCreate()">
        </el-input>
        <el-button @click="handleEmailCreate()" type="primary">Next step</el-button>
      </div>
      <div v-if="enrollStep == 2" class="input-email-item">
        <div>New enroll:</div>
        <div class="new-email-box">
          <div v-for="enroll in newEnrolls" :key="enroll">{{ enroll.email }}</div>
        </div>
        <el-button @click="backStep">Back</el-button>
        <el-button @click="addEnrollments" type="primary">Enroll in Course</el-button>
      </div>
    </div>


    <h1 class="people-title">Manage People</h1>
    <el-table style="width: 100%" :data="enrollments">
      <el-table-column type="index" width="50" />
      <el-table-column width="70">
        <template #default="scope">
          <el-avatar shape="square" :size="40" :src="scope.row.account.avatar" />
        </template>
      </el-table-column>
      <el-table-column prop="account.name" label="Name" width="180" />
      <el-table-column prop="account.email" label="Email" />
      <el-table-column prop="enroll_identity" label="Role"></el-table-column>
      <el-table-column label="Operations" width="180">
        <template #default="scope">
          <el-button @click="openEditDialog(scope.row)" size="small">Edit</el-button>
          <el-button type="danger" @click="$emit('delete-enrollment', scope.row.account.id)"
            size="small">Delete</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog title="Edit Account" v-model="editDialogVisible" class="people-dialog-container" :modalAppendToBody="false">
      <el-form :model="selectedAccount" label-width="auto">
          <el-form-item label="Email">
              <el-input class="editor-input-box" v-model="selectedAccount.account.email" autocomplete="off" style="width:95%;"></el-input>
          </el-form-item>
          <el-form-item label="Roles">
            <el-select v-model="selectedAccount.enroll_identity" placeholder="Select role" multiple style="width:95%;">
              <el-option v-for="role in peopleRoleList" :key="role" :label="role" :value="role" :disabled="checkIsModifable(role)"></el-option>
            </el-select>
          </el-form-item>
      </el-form>
      <template #footer>
          <el-button @click="editDialogVisible = false">Cancel</el-button>
          <el-button type="primary" @click="updateEnroll(selectedAccount)">Confirm</el-button>
      </template>
    </el-dialog>
  </div>

</template>
  
<script>
export default {
  emits: ['create-event', 'edit-event', 'delete-event', 'create-location', 'update-location', 'delete-location', 'new-enrolls', 'update-enrollment', 'delete-enrollment'],
  props: {
    attendanceEvents: Object,
    locations: Array,
    enrollments: Object, 
    currentRole: String
  },
  data() {
    return {
      localEnrollments: [],
      newEnrollmentEmails: '',
      newEnrolls: [],
      enrollStep: 1,
      peopleform: {
        owner: ['owner', 'instructor', 'staff', 'student'],
        instructor: ['staff', 'student'],
        staff: ['student']
      },
      peopleRoleList: ['owner', 'instructor', 'staff', 'student'],
      editDialogVisible: false,
      selectedAccount: {}
    }
  },
  watch: {
    enrollments: {
      deep: true,
      handler(newVal) {
        this.localEnrollments = newVal;
      }
    }
  },
  methods: {
    updateEnroll(account) {
      this.$emit('update-enrollment', account)
      this.editDialogVisible = false;
    },
    openEditDialog(account) {
      this.selectedAccount = JSON.parse(JSON.stringify(account))
      
      this.editDialogVisible = true;
    },
    checkIsModifable(role) {
      const availableRoles = this.peopleform[this.currentRole]
      return !availableRoles.includes(role)
    },
    onDialogClose() {
      this.$emit('dialog-closed')
    },
    backStep() {
      this.newEnrolls = []
      this.enrollStep = 1
    },
    addEnrollments() {
      this.$emit('new-enrolls', this.newEnrolls)
      this.newEnrolls = []
    },
    handleEmailCreate() {
      // Split the input by commas to support comma-separated emails
      let emails
      if(this.newEnrollmentEmails.indexOf(' ')>=0) {
        emails = this.newEnrollmentEmails.split(' ');
      }
      else {
        emails = this.newEnrollmentEmails.split(',');
      }
       
      emails.forEach(email => {
        if (email && !this.newEnrolls.some(user => user.email === email)) {
          this.newEnrolls.push({ email: email, roles: 'student' });
        }
      })
      this.newEnrollmentEmails = ''
      this.enrollStep = 2
    }
  }
}
</script>

<style>

.input-email-container {
  text-align: left;
  padding: 10px 40px 30px 40px;
  display: flex;
  justify-content: left;
  flex-wrap: wrap;
}

.input-email-item {
  margin: 0px;
  width: 100%;
}

.new-email-box {
  background-color: #fff;
  overflow: scroll;
  width: 100%;
  height: 100px;
  margin: 10px 0;
  padding: 10px;
  border-radius: 8px;
}

.people-title {
  margin: 30px 0 20px 20px;
  text-align: left;
}
.people-dialog-container {
  width: 600px;
}
@media (max-width: 768px) {
  .people-dialog-container {
      width: 100% !important;
  }
  .input-email-container {
    padding: 10px;
  }
}
</style>
  
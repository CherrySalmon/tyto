<template>
    <el-dialog title="Modify Attendance Event" v-model="showCreateAttendanceEventDialog" @close="onDialogClose" width="100%" :modalAppendToBody="false">
      <el-form ref="createAttendanceEventForm" :model="createAttendanceEventForm" label-width="auto">
        <el-form-item label="Name">
          <el-input v-model="createAttendanceEventForm.name" style="width:95%;"></el-input>
        </el-form-item>
        <el-form-item label="Location">
          <el-select v-model="createAttendanceEventForm.location_id" placeholder="Select" style="width:95%;">
            <el-option v-for="location in locations" :key="location.id" :label="location.name"
              :value="location.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="Start Time">
          <el-date-picker v-model="createAttendanceEventForm.start_at" type="datetime"
            placeholder="Select start time" style="width:95%;" time-format="HH:mm"></el-date-picker>
        </el-form-item>
        <el-form-item label="End Time">
          <el-date-picker v-model="createAttendanceEventForm.end_at" type="datetime"
            placeholder="Select end time" style="width:95%;" time-format="HH:mm"></el-date-picker>
        </el-form-item>
      </el-form>
      <span slot="footer" class="dialog-footer">
        <el-button @click="onDialogClose">Cancel</el-button>
        <el-button type="primary" @click="$emit('update-event', createAttendanceEventForm)">Confirm</el-button>
      </span>
    </el-dialog>
</template>
  
<script>
  export default {
    emits: ['dialog-closed', 'update-event'],
    props: {
      eventForm: {
        type: Object,
        default: () => ({})
      },
      visible: Boolean,
      locations: Array
    },
    data() {
        return {
            showCreateAttendanceEventDialog: false,
            createAttendanceEventForm: {
                name: '',
                location_id: '',
                start_at: '',
                end_at: '',
            },
        }
    },
    mounted() {
      this.createAttendanceEventForm = this.eventForm
      this.createAttendanceEventForm.start_at = new Date(this.createAttendanceEventForm.start_at)
      this.createAttendanceEventForm.end_at = new Date(this.createAttendanceEventForm.end_at)
      this.showCreateAttendanceEventDialog =  this.visible
    },
    methods: {
      onDialogClose() {
          this.showCreateAttendanceEventDialog = false
          this.$emit('dialog-closed')
      },
  }
}
</script>
  
<template>
  <el-dialog title="Modify Assignment" v-model="showDialog" @close="onDialogClose" width="100%" :modalAppendToBody="false">
    <el-form ref="assignmentForm" :model="localForm" label-width="auto">
      <el-form-item label="Title">
        <el-input v-model="localForm.title" placeholder="Assignment title" style="width:95%;"></el-input>
      </el-form-item>
      <el-form-item label="Description">
        <el-input v-model="localForm.description" type="textarea" :rows="4" placeholder="Markdown description" style="width:95%;"></el-input>
      </el-form-item>
      <el-form-item label="Due Date">
        <el-date-picker v-model="localForm.due_at" type="datetime" placeholder="Select due date" style="width:95%;" time-format="HH:mm"></el-date-picker>
      </el-form-item>
      <el-form-item label="Linked Event">
        <el-select v-model="localForm.event_id" placeholder="None (optional)" clearable style="width:95%;">
          <el-option v-for="event in attendanceEvents" :key="event.id" :label="event.name" :value="event.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="Allow Late Resubmits?">
        <el-switch v-model="localForm.allow_late_resubmit"></el-switch>
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="onDialogClose">Cancel</el-button>
      <el-button type="primary" @click="$emit('update-assignment', localForm)">Save</el-button>
    </template>
  </el-dialog>
</template>

<script>
export default {
  emits: ['dialog-closed', 'update-assignment'],
  props: {
    assignmentForm: {
      type: Object,
      default: () => ({})
    },
    visible: Boolean,
    attendanceEvents: Array
  },
  data() {
    return {
      showDialog: false,
      localForm: {
        title: '',
        description: '',
        due_at: '',
        event_id: null,
        allow_late_resubmit: false
      }
    }
  },
  mounted() {
    this.localForm = { ...this.assignmentForm }
    if (this.localForm.due_at) {
      this.localForm.due_at = new Date(this.localForm.due_at)
    }
    this.showDialog = this.visible
  },
  methods: {
    onDialogClose() {
      this.showDialog = false
      this.$emit('dialog-closed')
    }
  }
}
</script>

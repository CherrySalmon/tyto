<template>
  <el-dialog title="Create Assignment" v-model="showDialog" @close="onDialogClose" width="100%" :modalAppendToBody="false">
    <el-form ref="assignmentForm" :model="form" label-width="auto">
      <el-form-item label="Title">
        <el-input v-model="form.title" placeholder="Assignment title" style="width:95%;"></el-input>
      </el-form-item>
      <el-form-item label="Description">
        <el-input v-model="form.description" type="textarea" :rows="4" placeholder="Markdown description" style="width:95%;"></el-input>
      </el-form-item>
      <el-form-item label="Due Date">
        <el-date-picker v-model="form.due_at" type="datetime" placeholder="Select due date" style="width:95%;" time-format="HH:mm"></el-date-picker>
      </el-form-item>
      <el-form-item label="Linked Event">
        <el-select v-model="form.event_id" placeholder="None (optional)" clearable style="width:95%;">
          <el-option v-for="event in attendanceEvents" :key="event.id" :label="event.name" :value="event.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="Allow Late Resubmits?">
        <el-switch v-model="form.allow_late_resubmit"></el-switch>
      </el-form-item>

      <el-divider>Submission Requirements</el-divider>

      <div v-for="(req, index) in form.submission_requirements" :key="index" class="requirement-row">
        <el-form-item :label="'Requirement ' + (index + 1)">
          <div class="requirement-fields">
            <el-select v-model="req.submission_format" placeholder="Format" style="width: 100px;">
              <el-option label="File" value="file" />
              <el-option label="URL" value="url" />
            </el-select>
            <el-input v-model="req.description" placeholder="Description (e.g., R Markdown source file)" style="flex: 1; margin: 0 8px;"></el-input>
            <el-input
              v-if="req.submission_format === 'file'"
              v-model="req.allowed_types"
              placeholder=".Rmd,.pdf"
              style="width: 140px;"
            ></el-input>
            <el-button type="danger" :icon="Delete" circle size="small" @click="removeRequirement(index)" style="margin-left: 8px;"></el-button>
          </div>
        </el-form-item>
      </div>

      <el-button type="primary" plain @click="addRequirement" :disabled="hasEmptyRequirement" style="margin-left: 20px;">
        + Add Requirement
      </el-button>
    </el-form>
    <template #footer>
      <el-button @click="onDialogClose">Cancel</el-button>
      <el-button type="primary" @click="submitForm">Create</el-button>
    </template>
  </el-dialog>
</template>

<script>
import { Delete } from '@element-plus/icons-vue'

export default {
  emits: ['dialog-closed', 'create-assignment'],
  props: {
    visible: Boolean,
    attendanceEvents: Array
  },
  computed: {
    hasEmptyRequirement() {
      return this.form.submission_requirements.some(req => !req.description.trim())
    }
  },
  data() {
    return {
      Delete,
      showDialog: false,
      form: {
        title: '',
        description: '',
        due_at: '',
        event_id: null,
        allow_late_resubmit: false,
        submission_requirements: []
      }
    }
  },
  watch: {
    visible: {
      handler(newVal) {
        this.showDialog = newVal
        if (newVal) {
          this.resetForm()
        }
      }
    }
  },
  methods: {
    resetForm() {
      this.form = {
        title: '',
        description: '',
        due_at: '',
        event_id: null,
        allow_late_resubmit: false,
        submission_requirements: [{
          submission_format: 'file',
          description: '',
          allowed_types: '',
          sort_order: 0
        }]
      }
    },
    addRequirement() {
      this.form.submission_requirements.push({
        submission_format: 'file',
        description: '',
        allowed_types: '',
        sort_order: this.form.submission_requirements.length
      })
    },
    removeRequirement(index) {
      this.form.submission_requirements.splice(index, 1)
      this.form.submission_requirements.forEach((req, i) => {
        req.sort_order = i
      })
    },
    submitForm() {
      const data = { ...this.form }
      data.submission_requirements = data.submission_requirements
        .filter(req => req.description.trim() !== '')
        .map((req, i) => {
          const entry = {
            submission_format: req.submission_format,
            description: req.description,
            sort_order: i
          }
          if (req.submission_format === 'file' && req.allowed_types) {
            entry.allowed_types = req.allowed_types
          }
          return entry
        })
      this.$emit('create-assignment', data)
    },
    onDialogClose() {
      this.$emit('dialog-closed')
      this.showDialog = false
    }
  }
}
</script>

<style scoped>
.requirement-row {
  margin-bottom: 5px;
}

.requirement-fields {
  display: flex;
  align-items: center;
  width: 95%;
}
</style>

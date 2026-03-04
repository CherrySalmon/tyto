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

      <template v-if="assignmentStatus === 'draft'">
        <el-divider>Submission Requirements</el-divider>

        <div v-for="(req, index) in localForm.submission_requirements" :key="index" class="requirement-row">
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
                placeholder="Rmd,pdf"
                style="width: 140px;"
              ></el-input>
              <el-button type="danger" :icon="Delete" circle size="small" @click="removeRequirement(index)" style="margin-left: 8px;"></el-button>
            </div>
          </el-form-item>
        </div>

        <el-button type="primary" plain @click="addRequirement" :disabled="hasEmptyRequirement" style="margin-left: 20px;">
          + Add Requirement
        </el-button>
      </template>

      <template v-else>
        <el-divider>Submission Requirements</el-divider>
        <el-alert type="info" :closable="false" show-icon style="margin-bottom: 15px;">
          Requirements cannot be edited for published assignments. To edit requirements, unpublish the assignment first.
        </el-alert>
      </template>
    </el-form>
    <template #footer>
      <el-button @click="onDialogClose">Cancel</el-button>
      <el-button type="primary" @click="submitForm">Save</el-button>
    </template>
  </el-dialog>
</template>

<script>
import { Delete } from '@element-plus/icons-vue'

export default {
  emits: ['dialog-closed', 'update-assignment'],
  props: {
    assignmentForm: {
      type: Object,
      default: () => ({})
    },
    assignmentStatus: {
      type: String,
      default: 'draft'
    },
    visible: Boolean,
    attendanceEvents: Array
  },
  computed: {
    hasEmptyRequirement() {
      if (!this.localForm.submission_requirements) return false
      return this.localForm.submission_requirements.some(req => !req.description.trim())
    }
  },
  data() {
    return {
      Delete,
      showDialog: false,
      localForm: {
        title: '',
        description: '',
        due_at: '',
        event_id: null,
        allow_late_resubmit: false,
        submission_requirements: []
      }
    }
  },
  mounted() {
    this.localForm = {
      ...this.assignmentForm,
      submission_requirements: (this.assignmentForm.submission_requirements || []).map(req => ({
        submission_format: req.submission_format || 'file',
        description: req.description || '',
        allowed_types: req.allowed_types || '',
        sort_order: req.sort_order || 0
      }))
    }
    if (this.localForm.due_at) {
      this.localForm.due_at = new Date(this.localForm.due_at)
    }
    this.showDialog = this.visible
  },
  methods: {
    addRequirement() {
      this.localForm.submission_requirements.push({
        submission_format: 'file',
        description: '',
        allowed_types: '',
        sort_order: this.localForm.submission_requirements.length
      })
    },
    removeRequirement(index) {
      this.localForm.submission_requirements.splice(index, 1)
      this.localForm.submission_requirements.forEach((req, i) => {
        req.sort_order = i
      })
    },
    submitForm() {
      const data = { ...this.localForm }

      if (this.assignmentStatus === 'draft' && data.submission_requirements) {
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
      } else {
        delete data.submission_requirements
      }

      this.$emit('update-assignment', data)
    },
    onDialogClose() {
      this.showDialog = false
      this.$emit('dialog-closed')
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

<template>
  <el-dialog :title="assignment.title || 'Assignment'" v-model="showDialog" @close="onDialogClose" width="700px">
    <div v-if="assignment">
      <div class="detail-header">
        <el-tag :type="statusTagType(assignment.status)" size="small">
          {{ assignment.status }}
        </el-tag>
        <span v-if="assignment.due_at" class="detail-due">
          Due: {{ formatDateTime(assignment.due_at) }}
        </span>
        <span v-else class="detail-due">No due date</span>
      </div>

      <div v-if="assignment.description" class="detail-section">
        <h4>Description</h4>
        <div class="description-content" v-html="renderedDescription"></div>
      </div>

      <div v-if="assignment.submission_requirements && assignment.submission_requirements.length" class="detail-section">
        <h4>Submission Requirements</h4>
        <el-table :data="assignment.submission_requirements" style="width: 100%" size="small">
          <el-table-column type="index" width="50" label="#"></el-table-column>
          <el-table-column prop="description" label="Description"></el-table-column>
          <el-table-column prop="submission_format" label="Type" width="80">
            <template #default="scope">
              <el-tag size="small">{{ scope.row.submission_format }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="Allowed Types" width="150">
            <template #default="scope">
              {{ scope.row.allowed_types || '—' }}
            </template>
          </el-table-column>
        </el-table>
      </div>

      <div v-if="linkedEventName" class="detail-section">
        <h4>Linked Event</h4>
        <p>{{ linkedEventName }}</p>
      </div>

      <div class="detail-section detail-meta">
        <el-tag v-if="assignment.allow_late_resubmit" type="info" size="small">Late resubmission allowed</el-tag>
        <el-tag v-else type="info" size="small">Late resubmission not allowed</el-tag>
      </div>

      <!-- Student: Existing Submission -->
      <div v-if="mySubmission && !showSubmitForm" class="detail-section submission-section">
        <h4>Your Submission</h4>
        <div class="submission-info">
          <p>
            Submitted: {{ formatDateTime(mySubmission.submitted_at) }}
            <el-tag v-if="isLate(mySubmission.submitted_at)" type="danger" size="small" style="margin-left: 8px;">Late</el-tag>
          </p>
          <div v-if="mySubmission.requirement_uploads && mySubmission.requirement_uploads.length">
            <div v-for="upload in mySubmission.requirement_uploads" :key="upload.id" class="upload-entry">
              <span class="upload-label">{{ requirementDescription(upload.requirement_id) }}:</span>
              <a v-if="isUrl(upload)" :href="upload.content" target="_blank" rel="noopener">{{ upload.content }}</a>
              <span v-else>{{ upload.filename || upload.content }}</span>
            </div>
          </div>
          <el-button size="small" type="primary" @click="showSubmitForm = true" style="margin-top: 12px;">
            Resubmit
          </el-button>
        </div>
      </div>

      <!-- Student: Submission Form -->
      <div v-if="canSubmit && (!mySubmission || showSubmitForm)" class="detail-section submission-section">
        <h4>{{ mySubmission ? 'Resubmit' : 'Submit' }}</h4>
        <div v-if="assignment.submission_requirements && assignment.submission_requirements.length">
          <div v-for="req in assignment.submission_requirements" :key="req.id" class="submit-requirement">
            <label class="submit-label">
              {{ req.description }}
              <el-tag size="small" style="margin-left: 6px;">{{ req.submission_format }}</el-tag>
            </label>
            <el-input
              v-if="req.submission_format === 'url'"
              v-model="entryValues[req.id]"
              placeholder="Enter URL"
              clearable
            />
            <div v-else class="file-entry">
              <el-input
                v-model="entryValues[req.id]"
                placeholder="Enter filename (e.g., report.Rmd)"
                clearable
              />
              <p v-if="req.allowed_types" class="file-note">Allowed types: {{ req.allowed_types }}</p>
              <p class="file-note">File upload will be available soon — for now, enter the filename you plan to submit.</p>
            </div>
          </div>
          <div style="margin-top: 12px;">
            <el-button type="primary" @click="submitEntries" :disabled="!hasValidEntries">
              {{ mySubmission ? 'Resubmit' : 'Submit' }}
            </el-button>
            <el-button v-if="mySubmission" @click="showSubmitForm = false">Cancel</el-button>
          </div>
        </div>
        <p v-else class="no-requirements">No submission requirements defined for this assignment.</p>
      </div>

      <!-- Teaching Staff: All Submissions -->
      <div v-if="canViewAll && submissions.length" class="detail-section submission-section">
        <h4>All Submissions ({{ submissions.length }})</h4>
        <el-table :data="submissions" style="width: 100%" size="small">
          <el-table-column prop="account_id" label="Student ID" width="100"></el-table-column>
          <el-table-column label="Submitted" width="180">
            <template #default="scope">
              {{ formatDateTime(scope.row.submitted_at) }}
            </template>
          </el-table-column>
          <el-table-column label="Status" width="80">
            <template #default="scope">
              <el-tag v-if="isLate(scope.row.submitted_at)" type="danger" size="small">Late</el-tag>
              <el-tag v-else type="success" size="small">On time</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="Entries">
            <template #default="scope">
              {{ (scope.row.requirement_uploads || []).length }} / {{ (assignment.submission_requirements || []).length }}
            </template>
          </el-table-column>
        </el-table>
      </div>
      <div v-else-if="canViewAll && !submissionLoading" class="detail-section submission-section">
        <h4>All Submissions</h4>
        <p class="no-submissions">No submissions yet.</p>
      </div>
    </div>
  </el-dialog>
</template>

<script>
import { marked } from 'marked'
import { formatLocalDateTime } from '../../../lib/dates'

export default {
  emits: ['dialog-closed', 'create-submission'],
  props: {
    assignment: {
      type: Object,
      default: () => ({})
    },
    visible: Boolean,
    attendanceEvents: Array,
    submissions: {
      type: Array,
      default: () => []
    },
    submissionLoading: {
      type: Boolean,
      default: false
    }
  },
  data() {
    return {
      showDialog: false,
      showSubmitForm: false,
      entryValues: {}
    }
  },
  computed: {
    renderedDescription() {
      if (!this.assignment.description) return ''
      return marked.parse(this.assignment.description)
    },
    linkedEventName() {
      if (!this.assignment.event_id || !this.attendanceEvents) return null
      const event = this.attendanceEvents.find(e => e.id === this.assignment.event_id)
      return event ? event.name : null
    },
    canSubmit() {
      return this.assignment.policies && this.assignment.policies.can_submit
    },
    canViewAll() {
      // Teaching staff: first submission's policies will have can_view_all,
      // or fall back to assignment policies can_update (teaching staff indicator)
      if (this.submissions.length && this.submissions[0].policies) {
        return this.submissions[0].policies.can_view_all
      }
      return this.assignment.policies && this.assignment.policies.can_update
    },
    mySubmission() {
      if (!this.canSubmit) return null
      return this.submissions.length ? this.submissions[0] : null
    },
    hasValidEntries() {
      if (!this.assignment.submission_requirements) return false
      return this.assignment.submission_requirements.some(req => {
        return this.entryValues[req.id] && this.entryValues[req.id].trim()
      })
    }
  },
  watch: {
    visible: {
      handler(newVal) {
        this.showDialog = newVal
        if (newVal) {
          this.showSubmitForm = false
          this.entryValues = {}
          this.prefillEntries()
        }
      }
    }
  },
  methods: {
    formatDateTime(utcStr) {
      return formatLocalDateTime(utcStr)
    },
    statusTagType(status) {
      switch (status) {
        case 'draft': return 'warning'
        case 'published': return 'success'
        case 'disabled': return 'info'
        default: return ''
      }
    },
    isLate(submittedAt) {
      if (!this.assignment.due_at || !submittedAt) return false
      return new Date(submittedAt) > new Date(this.assignment.due_at)
    },
    isUrl(upload) {
      // A requirement_upload is a URL type if its content looks like a URL
      // (no filename/content_type set) or if the matching requirement is url type
      const req = this.findRequirement(upload.requirement_id)
      return req && req.submission_format === 'url'
    },
    findRequirement(requirementId) {
      if (!this.assignment.submission_requirements) return null
      return this.assignment.submission_requirements.find(r => r.id === requirementId)
    },
    requirementDescription(requirementId) {
      const req = this.findRequirement(requirementId)
      return req ? req.description : `Requirement #${requirementId}`
    },
    prefillEntries() {
      if (!this.mySubmission || !this.mySubmission.requirement_uploads) return
      this.mySubmission.requirement_uploads.forEach(upload => {
        const req = this.findRequirement(upload.requirement_id)
        if (!req) return
        if (req.submission_format === 'url') {
          this.entryValues[upload.requirement_id] = upload.content
        } else {
          this.entryValues[upload.requirement_id] = upload.filename || upload.content
        }
      })
    },
    submitEntries() {
      if (!this.assignment.submission_requirements) return
      const entries = this.assignment.submission_requirements
        .filter(req => this.entryValues[req.id] && this.entryValues[req.id].trim())
        .map(req => {
          const value = this.entryValues[req.id].trim()
          if (req.submission_format === 'url') {
            return {
              requirement_id: req.id,
              content: value,
              filename: null,
              content_type: null,
              file_size: null
            }
          }
          return {
            requirement_id: req.id,
            content: value,
            filename: value,
            content_type: null,
            file_size: null
          }
        })
      if (entries.length === 0) return
      this.$emit('create-submission', this.assignment.id, entries)
      this.showSubmitForm = false
    },
    onDialogClose() {
      this.$emit('dialog-closed')
      this.showDialog = false
    }
  }
}
</script>

<style scoped>
.detail-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.detail-due {
  font-size: 0.9rem;
  color: #666;
}

.detail-section {
  margin-bottom: 16px;
}

.detail-section h4 {
  margin-bottom: 8px;
  color: #333;
}

.description-content {
  padding: 12px;
  background-color: #fafafa;
  border-radius: 4px;
  line-height: 1.6;
}

.detail-meta {
  margin-top: 16px;
}

.submission-section {
  border-top: 1px solid #eee;
  padding-top: 16px;
}

.submission-info {
  background-color: #f5f7fa;
  padding: 12px;
  border-radius: 4px;
}

.upload-entry {
  margin: 6px 0;
}

.upload-label {
  font-weight: 600;
  margin-right: 8px;
}

.submit-requirement {
  margin-bottom: 12px;
}

.submit-label {
  display: block;
  margin-bottom: 4px;
  font-weight: 500;
}

.file-entry {
  max-width: 400px;
}

.file-note {
  font-size: 0.8rem;
  color: #909399;
  margin-top: 4px;
}

.no-requirements, .no-submissions {
  color: #909399;
  font-style: italic;
}
</style>

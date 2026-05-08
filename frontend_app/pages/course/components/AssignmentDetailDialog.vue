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

      <div v-if="linkedEventSummary" class="detail-section">
        <h4>Linked Event</h4>
        <p>
          {{ linkedEventSummary.name }}
          <span v-if="linkedEventSummary.start_at" class="event-start-at">
            — {{ formatDateTime(linkedEventSummary.start_at) }}
          </span>
        </p>
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
              <a v-else-if="upload.download_url" href="#" @click.prevent="downloadUpload(upload)">
                {{ upload.filename || 'Download' }}
              </a>
              <span v-else>{{ upload.filename || upload.content }}</span>
            </div>
          </div>
          <el-button v-if="canResubmit" size="small" type="primary" @click="showSubmitForm = true" style="margin-top: 12px;">
            Resubmit
          </el-button>
          <el-alert v-else type="info" :closable="false" show-icon style="margin-top: 12px;">
            The due date has passed and late resubmission is not allowed for this assignment. Your submission above is final.
          </el-alert>
        </div>
      </div>

      <!-- Student: Submission Form -->
      <div v-if="canSubmit && (!mySubmission || showSubmitForm)" class="detail-section submission-section">
        <h4>{{ mySubmission ? 'Resubmit' : 'Submit' }}</h4>
        <el-alert
          v-if="!mySubmission && isPastDue"
          type="warning"
          :closable="false"
          show-icon
          style="margin-bottom: 12px;"
        >
          This assignment is past its due date. Your submission will be marked late.
        </el-alert>
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
              <input
                type="file"
                :accept="acceptAttr(req)"
                @change="onFileChange(req, $event)"
                :ref="el => setFileInputRef(req.id, el)"
              />
              <div v-if="entryFiles[req.id]" class="file-pick">
                <span class="file-pick-name">{{ entryFiles[req.id].name }}</span>
                <span class="file-pick-size">({{ formatFileSize(entryFiles[req.id].size) }})</span>
                <el-button size="small" link type="primary" @click="clearFile(req.id)">Clear</el-button>
              </div>
              <div v-else-if="existingFilename(req.id)" class="file-pick">
                <span class="file-pick-existing">Currently submitted: {{ existingFilename(req.id) }}</span>
                <span class="file-pick-hint">— pick a file to replace it</span>
              </div>
              <p v-if="req.allowed_types" class="file-note">Allowed types: {{ req.allowed_types }}</p>
              <p class="file-note">Max {{ maxSizeMB }} MB per file.</p>
            </div>
          </div>
          <div style="margin-top: 12px;">
            <el-button type="primary" @click="submitEntries" :disabled="!hasValidEntries || submitting" :loading="submitting">
              {{ mySubmission ? 'Resubmit' : 'Submit' }}
            </el-button>
            <el-button v-if="mySubmission" @click="showSubmitForm = false" :disabled="submitting">Cancel</el-button>
          </div>
        </div>
        <p v-else class="no-requirements">No submission requirements defined for this assignment.</p>
      </div>

      <!-- Teaching Staff: All Submissions -->
      <div v-if="canViewAll && submissions.length" class="detail-section submission-section">
        <h4>All Submissions ({{ submissions.length }})</h4>
        <el-table
          ref="submissionsTable"
          :data="submissions"
          style="width: 100%"
          size="small"
          row-key="id"
          class="clickable-rows"
          @row-click="toggleSubmissionExpand"
        >
          <el-table-column type="expand">
            <template #default="scope">
              <div v-if="(scope.row.requirement_uploads || []).length" class="submission-expand">
                <div v-for="upload in scope.row.requirement_uploads" :key="upload.id" class="upload-entry">
                  <span class="upload-label">{{ requirementDescription(upload.requirement_id) }}:</span>
                  <a v-if="isUrl(upload)" :href="upload.content" target="_blank" rel="noopener">{{ upload.content }}</a>
                  <a v-else-if="upload.download_url" href="#" @click.prevent="downloadUpload(upload)">
                    {{ upload.filename || 'Download' }}
                  </a>
                  <span v-else>{{ upload.filename || upload.content }}</span>
                </div>
              </div>
              <p v-else class="no-submissions">No entries submitted.</p>
            </template>
          </el-table-column>
          <el-table-column label="Student">
            <template #default="scope">
              <div class="student-cell">
                <div>{{ studentDisplayName(scope.row) }}</div>
                <div v-if="scope.row.submitter && scope.row.submitter.email" class="student-email">
                  {{ scope.row.submitter.email }}
                </div>
              </div>
            </template>
          </el-table-column>
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
          <el-table-column label="Entries" width="90">
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
import { ElMessage } from 'element-plus'
import api from '@/lib/tytoApi'
import { formatLocalDateTime } from '../../../lib/dates'
import { MAX_SIZE_BYTES, MAX_SIZE_MB } from '../../../lib/fileLimits'

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
    },
    // Incremented by the parent whenever a submission attempt fails.
    // The dialog watches this to clear the in-flight state without
    // closing the submit form, so the user can see the error toast
    // and correct their input.
    submissionErrorNonce: {
      type: Number,
      default: 0
    }
  },
  data() {
    return {
      showDialog: false,
      showSubmitForm: false,
      submitting: false,
      entryValues: {},
      entryFiles: {},
      fileInputRefs: {},
      maxSizeMB: MAX_SIZE_MB
    }
  },
  computed: {
    renderedDescription() {
      if (!this.assignment.description) return ''
      return marked.parse(this.assignment.description)
    },
    // Prefer the backend-embedded linked_event summary (authoritative,
    // available to students who don't fetch the full attendance-events list).
    // Fall back to looking up the event in attendanceEvents for older payloads.
    linkedEventSummary() {
      if (this.assignment.linked_event) return this.assignment.linked_event
      if (!this.assignment.event_id || !this.attendanceEvents) return null
      const event = this.attendanceEvents.find(e => e.id === this.assignment.event_id)
      return event ? { id: event.id, name: event.name, start_at: event.start_at } : null
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
    isPastDue() {
      if (!this.assignment.due_at) return false
      return Date.now() > new Date(this.assignment.due_at).getTime()
    },
    // Mirrors backend rule in CreateSubmission: once a submission exists,
    // the due date has passed, and late resubmit is disallowed, the student
    // cannot resubmit. Hiding the button prevents a dead-end click.
    canResubmit() {
      if (!this.mySubmission) return true
      if (this.assignment.allow_late_resubmit) return true
      return !this.isPastDue
    },
    hasValidEntries() {
      if (!this.assignment.submission_requirements) return false
      return this.assignment.submission_requirements.some(req => {
        if (req.submission_format === 'url') {
          return this.entryValues[req.id] && this.entryValues[req.id].trim()
        }
        return Boolean(this.entryFiles[req.id])
      })
    }
  },
  watch: {
    visible: {
      handler(newVal) {
        this.showDialog = newVal
        if (newVal) {
          this.showSubmitForm = false
          this.submitting = false
          this.entryValues = {}
          this.entryFiles = {}
          // <input type="file"> keeps its native picked-file state across
          // dialog hide/show because el-dialog hides via CSS rather than
          // destroying. Reactively-bound entryFiles is empty, but the
          // browser's display still shows the previous filename until
          // we explicitly clear input.value.
          Object.values(this.fileInputRefs).forEach(el => {
            if (el) el.value = ''
          })
          this.prefillEntries()
        }
      }
    },
    // Close the submit form only after the parent confirms success
    // by refreshing submissions. A rejected submission leaves the
    // form open so the user sees the error toast without losing context.
    submissions() {
      if (this.submitting) {
        this.submitting = false
        this.showSubmitForm = false
      }
      // Backfill URL prefill if submissions arrived after the dialog
      // opened (parent fetches assignment + submissions in two awaits,
      // and the dialog watcher fires on the first one).
      if (this.showDialog && Object.keys(this.entryValues).length === 0) {
        this.prefillEntries()
      }
    },
    submissionErrorNonce() {
      // Parent signalled a failed submission — re-enable the form, keep it open.
      this.submitting = false
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
    studentDisplayName(submission) {
      if (submission.submitter?.name) return submission.submitter.name
      if (submission.submitter?.email) return submission.submitter.email
      return `Account #${submission.account_id}`
    },
    prefillEntries() {
      // URL-type values are prefilled so the user can edit them in place.
      // File-type entries cannot reconstruct a File from a stored filename —
      // existingFilename() shows the old name beside the picker so the user
      // knows what's currently submitted before deciding to replace it.
      if (!this.mySubmission || !this.mySubmission.requirement_uploads) return
      this.mySubmission.requirement_uploads.forEach(upload => {
        const req = this.findRequirement(upload.requirement_id)
        if (!req) return
        if (req.submission_format === 'url') {
          this.entryValues[upload.requirement_id] = upload.content
        }
      })
    },
    setFileInputRef(reqId, el) {
      if (el) {
        this.fileInputRefs[reqId] = el
      } else {
        delete this.fileInputRefs[reqId]
      }
    },
    acceptAttr(req) {
      if (!req.allowed_types) return ''
      // backend stores either ".rmd,.qmd" or "rmd,qmd" — normalise to ".ext"
      return req.allowed_types
        .split(',')
        .map(t => t.trim())
        .filter(Boolean)
        .map(t => (t.startsWith('.') ? t : `.${t}`))
        .join(',')
    },
    extensionAllowed(req, filename) {
      if (!req.allowed_types) return true
      const allowed = req.allowed_types
        .split(',')
        .map(t => t.trim().toLowerCase().replace(/^\./, ''))
        .filter(Boolean)
      const ext = (filename.split('.').pop() || '').toLowerCase()
      return allowed.includes(ext)
    },
    onFileChange(req, event) {
      const file = event.target.files && event.target.files[0]
      if (!file) {
        this.clearFile(req.id)
        return
      }
      if (!this.extensionAllowed(req, file.name)) {
        ElMessage({ type: 'error', message: `File type not allowed. Expected: ${req.allowed_types}` })
        this.resetFileInput(req.id)
        return
      }
      if (file.size > MAX_SIZE_BYTES) {
        ElMessage({ type: 'error', message: `File exceeds ${MAX_SIZE_MB} MB limit.` })
        this.resetFileInput(req.id)
        return
      }
      this.entryFiles[req.id] = file
    },
    clearFile(reqId) {
      delete this.entryFiles[reqId]
      this.resetFileInput(reqId)
    },
    resetFileInput(reqId) {
      const input = this.fileInputRefs[reqId]
      if (input) input.value = ''
    },
    existingFilename(reqId) {
      if (!this.mySubmission || !this.mySubmission.requirement_uploads) return null
      const existing = this.mySubmission.requirement_uploads.find(u => u.requirement_id === reqId)
      return existing ? existing.filename : null
    },
    formatFileSize(bytes) {
      if (bytes < 1024) return `${bytes} B`
      if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
      return `${(bytes / (1024 * 1024)).toFixed(2)} MB`
    },
    toggleSubmissionExpand(row) {
      // Element Plus stops propagation on the expand chevron's own click,
      // so this row-click handler only fires for clicks on cells outside
      // the chevron — turning the whole row into the affordance.
      this.$refs.submissionsTable.toggleRowExpansion(row)
    },
    async downloadUpload(upload) {
      // Plain <a href> can't carry our Bearer JWT, so we fetch the route
      // through axios (which adds Authorization), let the browser auto-follow
      // the 302 to the self-authenticating presigned URL, and deliver the
      // bytes as a blob download. Only the first hop needs our JWT — the
      // presigned URL auths via its signed query params.
      const path = upload.download_url.replace(/^\/api/, '')
      try {
        const response = await api.get(path, { responseType: 'blob' })
        const blobUrl = URL.createObjectURL(response.data)
        const a = document.createElement('a')
        a.href = blobUrl
        a.download = upload.filename || 'download'
        document.body.appendChild(a)
        a.click()
        document.body.removeChild(a)
        URL.revokeObjectURL(blobUrl)
      } catch (error) {
        const data = error.response?.data || {}
        const msg = data.details || data.error || 'Could not download file'
        ElMessage({ type: 'error', message: msg })
        console.error('Download failed:', error)
      }
    },
    submitEntries() {
      if (!this.assignment.submission_requirements) return
      const entries = []
      const files = {}
      this.assignment.submission_requirements.forEach(req => {
        if (req.submission_format === 'url') {
          const val = this.entryValues[req.id]
          if (!val || !val.trim()) return
          entries.push({
            requirement_id: req.id,
            content: val.trim(),
            filename: null,
            content_type: null,
            file_size: null
          })
          return
        }
        const file = this.entryFiles[req.id]
        if (!file) return
        entries.push({
          requirement_id: req.id,
          filename: file.name,
          content_type: file.type || 'application/octet-stream',
          file_size: file.size
        })
        files[req.id] = file
      })
      if (entries.length === 0) return
      this.submitting = true
      this.$emit('create-submission', this.assignment.id, entries, files)
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

.file-pick {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 6px;
  font-size: 0.875rem;
}

.file-pick-name {
  font-weight: 500;
  color: #333;
}

.file-pick-size {
  color: #909399;
}

.file-pick-existing {
  color: #606266;
}

.file-pick-hint {
  color: #909399;
  font-size: 0.8rem;
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

.event-start-at {
  color: #666;
}

.student-cell {
  line-height: 1.3;
}

.student-email {
  font-size: 0.75rem;
  color: #909399;
}

.submission-expand {
  padding: 8px 16px;
  background-color: #fafafa;
  border-radius: 4px;
}

.clickable-rows :deep(.el-table__row) {
  cursor: pointer;
}
</style>

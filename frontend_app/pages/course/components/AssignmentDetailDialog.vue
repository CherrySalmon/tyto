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
    </div>
  </el-dialog>
</template>

<script>
import { marked } from 'marked'
import { formatLocalDateTime } from '../../../lib/dates'

export default {
  emits: ['dialog-closed'],
  props: {
    assignment: {
      type: Object,
      default: () => ({})
    },
    visible: Boolean,
    attendanceEvents: Array
  },
  data() {
    return {
      showDialog: false
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
    }
  },
  watch: {
    visible: {
      handler(newVal) {
        this.showDialog = newVal
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
</style>

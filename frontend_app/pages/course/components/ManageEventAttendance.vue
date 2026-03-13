<template>
  <div>
    <p v-if="loading">Loading participants...</p>
    <el-table v-else :data="participants" style="width: 100%">
      <el-table-column prop="name" label="Name" />
      <el-table-column prop="email" label="Email" />
      <el-table-column label="Attended" width="120" align="center">
        <template #default="{ row }">
          <el-switch
            v-if="canManageAttendance"
            :model-value="row.attended"
            :loading="row.updating"
            @change="(val) => toggleAttendance(row, val)"
          />
          <span v-else>{{ row.attended ? 'Yes' : 'No' }}</span>
        </template>
      </el-table-column>
    </el-table>
  </div>
</template>

<script>
import api from '@/lib/tytoApi'
import { ElMessage } from 'element-plus'

export default {
  props: {
    courseId: { type: [Number, String], required: true },
    eventId: { type: [Number, String], required: true }
  },
  data() {
    return {
      participants: [],
      canManageAttendance: false,
      loading: true
    }
  },
  watch: {
    eventId: {
      immediate: true,
      handler() { this.fetchParticipants() }
    }
  },
  methods: {
    fetchParticipants() {
      this.loading = true
      api.get(`/course/${this.courseId}/attendance/${this.eventId}/participants`)
        .then(response => {
          this.participants = response.data.participants.map(p => ({ ...p, updating: false }))
          this.canManageAttendance = response.data.policies?.can_manage || false
        })
        .catch(error => {
          console.error('Error fetching participants:', error)
          ElMessage.error('Failed to load participants')
        })
        .finally(() => { this.loading = false })
    },
    toggleAttendance(participant, attended) {
      participant.updating = true
      api.put(
        `/course/${this.courseId}/attendance/${this.eventId}/participant/${participant.account_id}`,
        { attended }
      ).then(() => {
        participant.attended = attended
      }).catch(error => {
        console.error('Error updating attendance:', error)
        ElMessage.error(error.response?.data?.message || 'Failed to update attendance')
      }).finally(() => {
        participant.updating = false
      })
    }
  }
}
</script>

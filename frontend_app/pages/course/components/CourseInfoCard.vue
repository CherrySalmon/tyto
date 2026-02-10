<template>
  <el-card class="box-card">
    <template #header>
      <div class="card-header">
        <span>Course Information</span>
      </div>
    </template>
    <div>
      <p>Start Time: {{ getLocalDateString(course.start_at) || 'N/A' }}</p>
      <p>End Time: {{ getLocalDateString(course.end_at) || 'N/A' }}</p>
      <template v-if="course.policies">
        <div v-if="course.policies.can_update" style="text-align: center">
          <el-button type="warning" @click="$emit('show-modify-dialog')" text style="font-weight: 700;">Modify Course</el-button>
        </div>
      </template>
    </div>
  </el-card>
</template>
  
<script>
import { formatLocalDateTime } from '../../../lib/dateFormatter';

export default {
  props: ['course', 'currentRole'],
  emits: ['show-modify-dialog'],
  methods: {
    getLocalDateString(utcStr) {
      return formatLocalDateTime(utcStr)
    }
  }
}
</script>
  
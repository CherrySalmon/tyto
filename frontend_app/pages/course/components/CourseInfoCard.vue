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
      <template v-if="currentRole">
        <div v-if="currentRole != 'student'" style="text-align: center">
          <el-button type="warning" @click="$emit('show-modify-dialog')" text style="font-weight: 700;">Modify Course</el-button>
        </div>
      </template>
    </div>
  </el-card>
</template>
  
<script>
export default {
  props: ['course', 'currentRole'],
  emits: ['show-modify-dialog'],
  data() {
    return {}
  },
  methods: {
    getLocalDateString(utcStr=null) {
      if (!utcStr) {
        return false;
      }

      // Backend now returns ISO 8601 (UTC) strings, e.g. "2026-01-20T08:00:00Z"
      const date = new Date(utcStr);
      if (Number.isNaN(date.getTime())) {
        console.error('Invalid date value:', utcStr);
        return false;
      }

      // Formatting the Date object to a local date string
      return date.getFullYear()
        + '-' + String(date.getMonth() + 1).padStart(2, '0')
        + '-' + String(date.getDate()).padStart(2, '0')
        + ' ' + String(date.getHours()).padStart(2, '0')
        + ':' + String(date.getMinutes()).padStart(2, '0');
    }
  }
}
</script>
  
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
      if (typeof utcStr !== 'string') {
        return false;
      }
      // Manually parsing the date string to components
      const parts = utcStr.match(/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) \+0000/);
      if (!parts) {
        console.error('Invalid date format:', utcStr);
        return false;
      }

      // Creating a Date object using the parsed components
      // Note: Months are 0-indexed in JavaScript Date, hence the -1 on month part
      const date = new Date(Date.UTC(parts[1], parts[2] - 1, parts[3], parts[4], parts[5], parts[6]));

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
  
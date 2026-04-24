<template>
  <el-form :model="form" label-width="auto">
    <el-form-item label="Name">
      <el-input v-model="form.name" style="width:95%;" placeholder="e.g. Week 08 Lecture" />
    </el-form-item>
    <el-form-item label="Location">
      <el-select v-model="form.location_id" placeholder="Select" style="width:95%;">
        <el-option v-for="loc in locations" :key="loc.id" :label="loc.name" :value="loc.id" />
      </el-select>
    </el-form-item>
    <el-form-item label="Start Time">
      <el-date-picker
        v-model="form.start_at"
        type="datetime"
        placeholder="Select start time"
        style="width:95%;"
        time-format="HH:mm"
      />
    </el-form-item>
    <el-form-item label="End Time">
      <el-date-picker
        v-model="form.end_at"
        type="datetime"
        placeholder="Select end time"
        style="width:95%;"
        time-format="HH:mm"
      />
    </el-form-item>
  </el-form>
</template>

<script>
export default {
  name: 'SingleEventForm',
  emits: ['update:modelValue'],
  props: {
    modelValue: {
      type: Object,
      default: () => ({ name: '', location_id: '', start_at: '', end_at: '' })
    },
    locations: { type: Array, default: () => [] }
  },
  computed: {
    form: {
      get() { return this.modelValue },
      set(val) { this.$emit('update:modelValue', val) }
    }
  }
}
</script>

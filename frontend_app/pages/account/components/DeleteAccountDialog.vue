<template>
  <el-dialog
    :model-value="modelValue"
    title="Delete account"
    width="100%"
    style="max-width: 480px;"
    @update:model-value="close"
  >
    <el-alert :title="warning" type="warning" :closable="false" show-icon style="margin-bottom: 14px;" />
    <p class="prompt">Type <code>{{ account.email }}</code> to confirm.</p>
    <el-input v-model="typed" placeholder="email address" autocomplete="off" />
    <template #footer>
      <el-button @click="close">Cancel</el-button>
      <el-button type="danger" :disabled="!matches" :loading="deleting" @click="confirm">Delete account</el-button>
    </template>
  </el-dialog>
</template>

<script>
// Plan Q7: deleting an account cascades its enrollments and attendance
// records, so the confirm names what goes and needs the email typed in.
export default {
  props: {
    modelValue: { type: Boolean, default: false },
    account: { type: Object, required: true },
    enrollmentCount: { type: Number, default: null },
    deleting: { type: Boolean, default: false }
  },
  emits: ['update:modelValue', 'confirm'],
  data() {
    return { typed: '' }
  },
  computed: {
    matches() {
      return this.typed.trim() === this.account.email
    },
    warning() {
      const who = this.account.name || this.account.email
      const count = this.enrollmentCount === null ? 'their' : `${this.enrollmentCount}`
      const noun = this.enrollmentCount === 1 ? 'course enrollment' : 'course enrollments'
      return `This removes ${who}'s ${count} ${noun} and all their attendance records. It cannot be undone.`
    }
  },
  watch: {
    modelValue(open) {
      if (!open) this.typed = ''
    }
  },
  methods: {
    confirm() {
      if (this.matches) this.$emit('confirm', this.account)
    },
    close() {
      this.$emit('update:modelValue', false)
    }
  }
}
</script>

<style scoped>
.prompt {
  margin: 0 0 8px;
}
</style>

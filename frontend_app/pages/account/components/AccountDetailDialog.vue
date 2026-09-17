<template>
  <el-dialog
    :model-value="modelValue"
    title="Account"
    width="100%"
    style="max-width: 640px;"
    @update:model-value="close"
  >
    <div class="detail">
    <el-alert v-if="error" :title="error" type="error" :closable="false" />
    <template v-else-if="detail">
      <div class="who">
        <el-avatar shape="square" :size="44" :src="detail.avatar" />
        <div class="who-text">
          <div class="who-name">{{ displayName(detail) }}</div>
          <div class="who-email">{{ detail.email }}</div>
        </div>
        <div class="who-roles">
          <el-tag v-for="role in detail.roles" :key="role" size="small" class="role-tag">{{ roleLabel(role) }}</el-tag>
        </div>
      </div>
      <dl class="facts">
        <dt>Added on</dt><dd>{{ addedOn }}</dd>
        <dt>System roles</dt><dd>{{ detail.roles.map(roleLabel).join(', ') || 'None' }}</dd>
      </dl>
      <div class="list-heading">Enrollments <span>{{ enrollmentSummary }}</span></div>
      <div v-if="detail.enrollments.length" class="enrollments">
        <div v-for="membership in detail.enrollments" :key="membership.course_id" class="enrollment">
          <span class="course-name">{{ membership.course_name }}</span>
          <span>
            <el-tag v-for="role in membership.roles" :key="role" size="small" type="primary" class="role-tag">{{ role }}</el-tag>
          </span>
        </div>
      </div>
      <div v-else class="hint">Not enrolled in any course.</div>
      <div class="hint">Enrollments are edited from each course's People tab.</div>
    </template>
    <div v-else class="hint">Loading…</div>
    </div>
    <template #footer>
      <el-button type="primary" @click="close">Close</el-button>
    </template>
  </el-dialog>
</template>

<script>
import api from '@/lib/tytoApi'
import { roleLabel } from '@/lib/roles'
import { displayName } from '@/lib/accountsTable'

// Plan Q3: read-only account detail with a scrollable list of course
// enrollments, loaded from GET /account/:id when the dialog opens.
export default {
  props: {
    modelValue: { type: Boolean, default: false },
    accountId: { type: Number, default: null }
  },
  emits: ['update:modelValue'],
  data() {
    return { detail: null, error: '' }
  },
  computed: {
    addedOn() {
      return this.detail?.created_at ? this.detail.created_at.slice(0, 10) : 'Unknown'
    },
    enrollmentSummary() {
      const n = this.detail?.enrollments.length ?? 0
      return `${n} ${n === 1 ? 'course' : 'courses'}`
    }
  },
  watch: {
    accountId: { immediate: true, handler: 'load' },
    modelValue(open) {
      if (open) this.load()
    }
  },
  methods: {
    roleLabel,
    displayName,
    async load() {
      if (!this.modelValue || !this.accountId) return
      this.detail = null
      this.error = ''
      try {
        const { data } = await api.get(`/account/${this.accountId}`)
        this.detail = data.data
      } catch (err) {
        this.error = err.response?.data?.details || 'Could not load this account.'
      }
    },
    close() {
      this.$emit('update:modelValue', false)
    }
  }
}
</script>

<style scoped>
/* The app centres text globally; the detail reads as a record, left-aligned. */
.detail {
  text-align: left;
}

.who {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}

.who-text {
  flex: 1;
  min-width: 0;
}

.who-name {
  font-size: 16px;
  font-weight: 600;
}

.who-email {
  color: var(--el-text-color-secondary);
  overflow-wrap: anywhere;
}

.facts {
  display: grid;
  grid-template-columns: 110px 1fr;
  gap: 4px 12px;
  margin: 0 0 14px;
  font-size: 14px;
}

.facts dt {
  color: var(--el-text-color-secondary);
}

.facts dd {
  margin: 0;
}

.list-heading {
  font-weight: 600;
  margin-bottom: 6px;
}

.list-heading span {
  font-weight: 400;
  color: var(--el-text-color-secondary);
}

.enrollments {
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 4px;
  max-height: 220px;
  overflow-y: auto;
}

.enrollment {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-bottom: 1px solid var(--el-border-color-lighter);
}

.enrollment:last-child {
  border-bottom: 0;
}

.role-tag {
  margin-left: 4px;
}

.hint {
  font-size: 12px;
  color: var(--el-text-color-secondary);
  margin-top: 8px;
}
</style>

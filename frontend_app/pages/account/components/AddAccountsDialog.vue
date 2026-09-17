<template>
  <el-dialog
    :model-value="modelValue"
    title="Add accounts"
    width="100%"
    style="max-width: 680px;"
    :close-on-click-modal="!submitting"
    @update:model-value="close"
  >
    <el-steps :active="step" finish-status="success" simple style="margin-bottom: 16px;">
      <el-step title="Paste emails" />
      <el-step title="Set roles" />
    </el-steps>

    <!-- Step 1: paste -->
    <div v-if="step === 1">
      <el-input
        v-model="rawEmails"
        type="textarea"
        :rows="5"
        placeholder="one@example.edu, two@example.edu"
        :disabled="submitting"
      />
      <div class="hint">
        Google-based emails only. Separate with spaces, commas, or new lines.
        <span v-if="rawEmails.trim()">{{ parsed.emails.length }} emails found, {{ parsed.skipped.length }} skipped.</span>
      </div>
      <el-alert v-if="submitError" :title="submitError" type="error" :closable="false" style="margin-top: 12px;" />
    </div>

    <!-- Step 2: results with role editors -->
    <div v-else>
      <el-alert :title="summary" type="success" :closable="false" style="margin-bottom: 12px;" />
      <table class="results">
        <thead>
          <tr><th>Email</th><th>Status</th><th>System roles</th></tr>
        </thead>
        <tbody>
          <tr v-for="row in rows" :key="row.key">
            <td>{{ row.email }}</td>
            <td><el-tag :type="statusType(row.status)" size="small">{{ row.status }}</el-tag></td>
            <td>
              <el-select
                v-if="row.account"
                v-model="row.account.roles"
                multiple
                size="small"
                placeholder="No roles"
                class="roles-select"
                @change="saveRoles(row.account)"
              >
                <el-option v-for="option in roleOptions" :key="option.value" :label="option.label" :value="option.value" />
              </el-select>
              <span v-else class="hint">Skipped</span>
            </td>
          </tr>
        </tbody>
      </table>
      <div class="hint" style="margin-top: 10px;">
        Each role change saves right away. New account holders sign in at this app's login page with their Google account.
      </div>
      <el-alert v-if="submitError" :title="submitError" type="error" :closable="false" style="margin-top: 12px;" />
    </div>

    <template #footer>
      <template v-if="step === 1">
        <el-button :disabled="submitting" @click="close">Cancel</el-button>
        <el-button type="primary" :loading="submitting" :disabled="!canSubmit" @click="submit">
          Add {{ parsed.emails.length }} {{ parsed.emails.length === 1 ? 'account' : 'accounts' }}
        </el-button>
      </template>
      <template v-else>
        <el-button @click="addMore">Add more</el-button>
        <el-button type="primary" @click="finish">Done</el-button>
      </template>
    </template>
  </el-dialog>
</template>

<script>
import api from '@/lib/tytoApi'
import { roleOptions } from '@/lib/roles'
import { parseEmails } from '@/lib/parseEmails'

const STATUS = { created: 'added', existing: 'already existed', invalid: 'invalid' }

// Two-step bulk add (plan Q1/Q2): paste emails, then set roles on the rows
// the server reports back. Every new account starts as `member` only; role
// changes on step 2 save one by one through PUT /account/:id.
export default {
  props: { modelValue: { type: Boolean, default: false } },
  emits: ['update:modelValue', 'done'],
  data() {
    return {
      step: 1,
      rawEmails: '',
      submitting: false,
      submitError: '',
      rows: [],
      counts: { created: 0, existing: 0, invalid: 0 },
      roleOptions
    }
  },
  computed: {
    parsed() {
      return parseEmails(this.rawEmails)
    },
    canSubmit() {
      return this.parsed.emails.length > 0 && !this.submitting
    },
    summary() {
      const { created, existing, invalid } = this.counts
      const parts = [`${created} ${created === 1 ? 'account' : 'accounts'} added as ${created === 1 ? 'a member' : 'members'}.`]
      if (existing) parts.push(`${existing} already existed.`)
      if (invalid) parts.push(`${invalid} ${invalid === 1 ? 'was' : 'were'} not a valid email.`)
      return parts.join(' ')
    }
  },
  methods: {
    async submit() {
      this.submitting = true
      this.submitError = ''
      try {
        // Send skipped tokens too: the server is the authority on validity and
        // reports them back under `invalid`, so the results list is complete.
        const emails = [...this.parsed.emails, ...this.parsed.skipped]
        const { data } = await api.post('/account/bulk', { emails })
        this.rows = [
          ...data.created.map((account) => ({ key: account.id, email: account.email, status: STATUS.created, account })),
          ...data.existing.map((account) => ({ key: account.id, email: account.email, status: STATUS.existing, account })),
          ...data.invalid.map((email) => ({ key: `invalid:${email}`, email, status: STATUS.invalid, account: null }))
        ]
        this.counts = { created: data.created.length, existing: data.existing.length, invalid: data.invalid.length }
        this.step = 2
      } catch (error) {
        this.submitError = error.response?.data?.details || 'Could not add accounts. Please try again.'
      } finally {
        this.submitting = false
      }
    },
    async saveRoles(account) {
      this.submitError = ''
      try {
        await api.put(`/account/${account.id}`, { roles: account.roles })
      } catch (error) {
        this.submitError = error.response?.data?.details || `Could not save roles for ${account.email}.`
      }
    },
    statusType(status) {
      if (status === STATUS.created) return 'success'
      if (status === STATUS.existing) return 'info'
      return 'danger'
    },
    addMore() {
      this.rawEmails = ''
      this.submitError = ''
      this.step = 1
    },
    finish() {
      this.$emit('done')
      this.close()
    },
    close() {
      this.$emit('update:modelValue', false)
      this.reset()
    },
    reset() {
      this.step = 1
      this.rawEmails = ''
      this.submitError = ''
      this.rows = []
      this.counts = { created: 0, existing: 0, invalid: 0 }
    }
  }
}
</script>

<style scoped>
.hint {
  font-size: 12px;
  color: var(--el-text-color-secondary);
  margin-top: 6px;
}

.results {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}

.results th,
.results td {
  text-align: left;
  padding: 8px 10px;
  border-bottom: 1px solid var(--el-border-color-lighter);
  vertical-align: middle;
}

.results th {
  color: var(--el-text-color-secondary);
  font-weight: 600;
  font-size: 13px;
}

.roles-select {
  min-width: 200px;
}
</style>

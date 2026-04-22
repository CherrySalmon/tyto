<template>
  <div class="bulk-step1">
    <!-- Name pattern -->
    <div class="panel">
      <div class="panel__label">
        Name pattern
        <span class="panel__req">*</span>
        <el-tooltip placement="top" content="You can edit any individual name on the next step.">
          <el-icon class="panel__info"><QuestionFilled /></el-icon>
        </el-tooltip>
      </div>
      <div class="panel__row">
        <el-input
          v-model="state.prefix"
          placeholder="Week"
          style="width: 140px;"
          :class="{ 'is-invalid': attempted && !state.prefix.trim() }"
        />
        <el-select v-model="state.nameFormat" style="width: 180px;">
          <el-option value="pad2" label="→ 01, 02, 03 …" />
          <el-option value="nopad" label="→ 1, 2, 3 …" />
          <el-option value="date-short" label="→ Aug 26" />
          <el-option value="none" label="(no suffix)" />
        </el-select>
        <template v-if="state.nameFormat === 'pad2' || state.nameFormat === 'nopad'">
          <span class="panel__muted">starting at</span>
          <el-input v-model="state.startNum" placeholder="8" style="width: 70px;" />
        </template>
        <span class="panel__preview">
          Preview: <b>{{ previewName(0) }}</b>
          <template v-if="state.selectedDates.length > 1">, {{ previewName(1) }}</template>
          <template v-if="state.selectedDates.length > 2">, {{ previewName(2) }}…</template>
        </span>
      </div>
    </div>

    <!-- Shared details -->
    <div class="panel">
      <div class="panel__label">
        Shared details
        <el-tooltip placement="top" content="These apply to every date. You can override individual events on the next step.">
          <el-icon class="panel__info"><QuestionFilled /></el-icon>
        </el-tooltip>
      </div>
      <el-form label-width="100px" class="panel__form">
        <el-form-item label="Location" required>
          <el-select
            v-model="state.sharedLoc"
            placeholder="Select"
            style="width: 100%;"
            :class="{ 'is-invalid': attempted && !state.sharedLoc }"
          >
            <el-option
              v-for="loc in locations"
              :key="loc.id"
              :label="loc.name"
              :value="loc.id"
            />
          </el-select>
        </el-form-item>
        <div class="panel__row-times">
          <el-form-item label="Start time" required>
            <TimeInput
              v-model="state.sharedStart"
              :invalid="attempted && !state.sharedStart"
            />
          </el-form-item>
          <el-form-item label="End time" label-width="80px" required>
            <TimeInput
              v-model="state.sharedEnd"
              :invalid="attempted && !state.sharedEnd"
            />
          </el-form-item>
        </div>
      </el-form>
    </div>

    <!-- Calendar strip -->
    <EventCalendarStrip
      :selected-dates="state.selectedDates"
      :existing-dates="existingDates"
      :month-count="state.monthCount"
      :course-start-at="courseStartAt"
      :invalid="attempted && state.selectedDates.length === 0"
      @toggle-date="toggleDate"
      @update:month-count="v => (state.monthCount = v)"
    />

    <div class="qp-row">
      <span class="qp-row__label">Quick pick:</span>
      <QuickPickChips @apply="applyQuickPick" />
      <span class="qp-row__legend">
        <span class="qp-row__dot" />
        existing event
      </span>
      <button
        v-if="state.selectedDates.length > 0"
        type="button"
        class="qp-row__clear"
        @click="clearDates"
      >Clear</button>
    </div>
  </div>
</template>

<script>
import TimeInput from './TimeInput.vue'
import EventCalendarStrip from './EventCalendarStrip.vue'
import QuickPickChips from './QuickPickChips.vue'

const pad2 = n => String(n).padStart(2, '0')
const fmtDateISO = d => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
const fmtDateShort = d => d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })

export function buildName(prefix, format, startNum, i, iso) {
  const p = prefix || ''
  const n = parseInt(startNum || '1', 10) + i
  if (format === 'pad2') return `${p}${pad2(n)}`
  if (format === 'nopad') return `${p}${n}`
  if (format === 'date-short') {
    const pt = p.trim()
    if (!iso) return pt
    const d = new Date(`${iso}T00:00`)
    const short = fmtDateShort(d)
    return pt ? `${pt} — ${short}` : short
  }
  if (format === 'none') return p
  return `${p}${pad2(n)}`
}

export default {
  name: 'BulkEventsStep1Dates',
  components: { TimeInput, EventCalendarStrip, QuickPickChips },
  emits: ['update:state'],
  props: {
    modelState: {
      type: Object,
      required: true
    },
    locations: { type: Array, default: () => [] },
    existingDates: { type: Array, default: () => [] },
    courseStartAt: { type: [String, Date], default: null },
    courseEndAt: { type: [String, Date], default: null },
    attempted: { type: Boolean, default: false }
  },
  computed: {
    state: {
      get() { return this.modelState },
      set(val) { this.$emit('update:state', val) }
    }
  },
  methods: {
    previewName(i) {
      const iso = this.state.selectedDates[i] || fmtDateISO(new Date())
      return buildName(this.state.prefix, this.state.nameFormat, this.state.startNum, i, iso)
    },
    toggleDate(iso) {
      const set = new Set(this.state.selectedDates)
      if (set.has(iso)) set.delete(iso)
      else set.add(iso)
      this.state.selectedDates = Array.from(set).sort()
    },
    applyQuickPick({ dows }) {
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const start = this.courseStartAt ? new Date(this.courseStartAt) : null
      const end = this.courseEndAt ? new Date(this.courseEndAt) : null
      const from = start && !isNaN(start.getTime()) ? start : today
      // Fallback: if course end is unknown, project 8 weeks forward from today
      const fallbackEnd = new Date(today)
      fallbackEnd.setDate(fallbackEnd.getDate() + 7 * 8)
      const to = end && !isNaN(end.getTime()) && end > from ? end : fallbackEnd

      const picked = new Set(this.state.selectedDates)
      const dowSet = new Set(dows)
      const cursor = new Date(from)
      while (cursor <= to) {
        if (dowSet.has(cursor.getDay())) {
          picked.add(fmtDateISO(cursor))
        }
        cursor.setDate(cursor.getDate() + 1)
      }
      this.state.selectedDates = Array.from(picked).sort()
    },
    clearDates() {
      this.state.selectedDates = []
    }
  }
}
</script>

<style scoped>
.bulk-step1 {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.panel {
  padding: 14px;
  background: #fff;
  border: 1px solid #ebeef5;
  border-radius: 4px;
}
.panel__label {
  font-size: 12px;
  font-weight: 700;
  color: #606266;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 8px;
}
.panel__req {
  color: #f56c6c;
  font-weight: 400;
  margin-left: 4px;
}
.panel__row {
  display: flex;
  gap: 8px;
  align-items: center;
  flex-wrap: wrap;
}
.panel__muted {
  font-size: 12px;
  color: #909399;
}
.panel__preview {
  font-size: 12px;
  color: #909399;
  margin-left: auto;
}
.panel__preview b {
  color: #303133;
}
.panel__info {
  font-size: 13px;
  color: #909399;
  margin-left: 4px;
  vertical-align: middle;
  cursor: help;
}
.panel__form {
  margin-top: 6px;
}
.panel__row-times {
  display: flex;
  gap: 16px;
}
.qp-row {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  margin-top: -4px;
}
.qp-row__label {
  font-size: 11px;
  font-weight: 600;
  color: #606266;
}
.qp-row__legend {
  font-size: 11px;
  color: #909399;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-left: auto;
}
.qp-row__dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  border-radius: 4px;
  background: #fdf6ec;
  border: 1px solid #e6a23c;
}
.qp-row__clear {
  background: transparent;
  border: none;
  color: #409eff;
  font-size: 11px;
  cursor: pointer;
  font-family: inherit;
}
.is-invalid :deep(.el-input__wrapper) {
  box-shadow: 0 0 0 1px #f56c6c inset;
  background: #fef6f6;
}
</style>

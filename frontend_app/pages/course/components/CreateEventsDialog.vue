<template>
  <el-dialog
    v-model="show"
    :title="headerTitle"
    :width="modalWidth"
    :close-on-click-modal="!submitting"
    :close-on-press-escape="!submitting"
    :show-close="!submitting"
    :modal-append-to-body="false"
  >
    <template #header>
      <div v-if="view === 'single'" class="ce-header">
        <div class="ce-header__title">{{ headerTitle }}</div>
      </div>
      <div v-else class="ce-header ce-header--step">
        <div class="ce-header__step">Step {{ view === 'bulk-dates' ? 1 : 2 }} of 2</div>
        <div class="ce-header__title">{{ headerTitle }}</div>
        <div class="ce-header__subtitle">{{ headerSubtitle }}</div>
        <div class="ce-header__progress">
          <div class="ce-header__bar" :class="{ 'ce-header__bar--active': true }" />
          <div class="ce-header__bar" :class="{ 'ce-header__bar--active': view === 'bulk-review' }" />
        </div>
      </div>
    </template>

    <!-- Bulk toggle (visible on single + bulk-dates) -->
    <div v-if="view === 'single'" class="ce-toggle">
      <label>
        <input type="checkbox" :checked="false" :disabled="submitting" @change="goToBulkDates" />
        <span class="ce-toggle__title">Create multiple at once</span>
        <span class="ce-toggle__hint">— pick several dates sharing a location and time</span>
      </label>
    </div>
    <div v-else-if="view === 'bulk-dates'" class="ce-toggle ce-toggle--active">
      <label>
        <input type="checkbox" :checked="true" :disabled="submitting" @change="goToSingle" />
        <span class="ce-toggle__title">Create multiple at once</span>
        <span class="ce-toggle__hint">— uncheck to create a single event</span>
      </label>
    </div>

    <!-- Views -->
    <Transition name="ce-fade" mode="out-in">
      <SingleEventForm
        v-if="view === 'single'"
        v-model="singleForm"
        :locations="locations"
      />
      <BulkEventsStep1Dates
        v-else-if="view === 'bulk-dates'"
        :model-state="step1State"
        :locations="locations"
        :existing-dates="existingEventDates"
        :course-start-at="courseStartAt"
        :course-end-at="courseEndAt"
        :attempted="attempted"
        @update:state="v => (step1State = v)"
      />
      <BulkEventsStep2Review
        v-else-if="view === 'bulk-review'"
        :model-rows="rows"
        :locations="locations"
        :errors="rowErrors"
        :max-rows="MAX_ROWS"
        @update:rows="v => (rows = v)"
      />
    </Transition>

    <template #footer>
      <div class="ce-footer">
        <div class="ce-footer__status">{{ statusMessage }}</div>
        <div class="ce-footer__actions">
          <el-button :disabled="submitting" @click="cancel">Cancel</el-button>
          <el-button
            v-if="view === 'single'"
            type="primary"
            :loading="submitting"
            :disabled="submitting || !canConfirmSingle"
            @click="confirmSingle"
          >Create event</el-button>
          <el-button
            v-else-if="view === 'bulk-dates'"
            type="primary"
            :disabled="submitting"
            @click="tryGoToReview"
          >Review {{ step1State.selectedDates.length || '' }} event{{ step1State.selectedDates.length === 1 ? '' : 's' }} →</el-button>
          <el-button
            v-else-if="view === 'bulk-review'"
            type="primary"
            :loading="submitting"
            :disabled="submitting || !canConfirmBulk"
            @click="confirmBulk"
          >Create {{ rows.length }} event{{ rows.length === 1 ? '' : 's' }}</el-button>
        </div>
      </div>
    </template>
  </el-dialog>
</template>

<script>
import SingleEventForm from './events/SingleEventForm.vue'
import BulkEventsStep1Dates, { buildName } from './events/BulkEventsStep1Dates.vue'
import BulkEventsStep2Review from './events/BulkEventsStep2Review.vue'

const MAX_ROWS = 100

function emptySingleForm() {
  return { name: '', location_id: '', start_at: '', end_at: '' }
}

function emptyStep1State(monthCount = 2) {
  return {
    selectedDates: [],
    prefix: 'Week',
    nameFormat: 'pad2',
    startNum: '1',
    sharedLoc: '',
    sharedStart: '',
    sharedEnd: '',
    monthCount
  }
}

function computeCalendarAnchor(courseStartAt) {
  const s = courseStartAt ? new Date(courseStartAt) : null
  const ref = s && !isNaN(s.getTime()) ? s : new Date()
  return new Date(ref.getFullYear(), ref.getMonth(), 1)
}

function computeMonthSpan(courseStartAt, courseEndAt) {
  const anchor = computeCalendarAnchor(courseStartAt)
  const e = courseEndAt ? new Date(courseEndAt) : null
  if (!e || isNaN(e.getTime())) return 2
  if (e < anchor) return 1
  const months = (e.getFullYear() - anchor.getFullYear()) * 12 + (e.getMonth() - anchor.getMonth()) + 1
  return Math.max(1, months)
}

export default {
  name: 'CreateEventsDialog',
  components: { SingleEventForm, BulkEventsStep1Dates, BulkEventsStep2Review },
  emits: ['dialog-closed', 'create-events'],
  props: {
    visible: { type: Boolean, default: false },
    locations: { type: Array, default: () => [] },
    existingEventDates: { type: Array, default: () => [] },
    submitting: { type: Boolean, default: false },
    rowErrors: { type: Object, default: () => ({}) },
    courseStartAt: { type: [String, Date], default: null },
    courseEndAt: { type: [String, Date], default: null }
  },
  data() {
    return {
      show: false,
      view: 'single',
      singleForm: emptySingleForm(),
      step1State: emptyStep1State(),
      rows: [],
      attempted: false,
      MAX_ROWS
    }
  },
  computed: {
    headerTitle() {
      return this.view === 'single' ? 'Create Attendance Event' : 'Create Attendance Events'
    },
    headerSubtitle() {
      if (this.view === 'bulk-dates') return 'Pick dates and shared details'
      if (this.view === 'bulk-review') return 'Review & refine each event'
      return ''
    },
    modalWidth() {
      if (this.view === 'bulk-review') return '1160px'
      if (this.view === 'bulk-dates') return '820px'
      return '560px'
    },
    canConfirmSingle() {
      const f = this.singleForm
      return !!(f.name && f.location_id && f.start_at && f.end_at)
    },
    bulkStep1Valid() {
      const s = this.step1State
      return (
        s.selectedDates.length > 0 &&
        s.sharedLoc !== '' &&
        s.sharedStart &&
        s.sharedEnd &&
        (s.prefix || '').trim()
      )
    },
    canConfirmBulk() {
      if (this.rows.length === 0 || this.rows.length > MAX_ROWS) return false
      return this.rows.every(r => r.name && r.date && r.locationId && r.startTime && r.endTime)
    },
    statusMessage() {
      if (this.view === 'single') {
        if (this.canConfirmSingle) return 'Ready to create'
        if (this.attempted) {
          const miss = []
          if (!this.singleForm.name) miss.push('name')
          if (!this.singleForm.location_id) miss.push('location')
          if (!this.singleForm.start_at) miss.push('start')
          if (!this.singleForm.end_at) miss.push('end')
          return `Missing: ${miss.join(', ')}`
        }
        return 'Fill in required fields'
      }
      if (this.view === 'bulk-dates') {
        if (!this.attempted || this.bulkStep1Valid) {
          const n = this.step1State.selectedDates.length
          return n === 0 ? 'Pick at least one date to continue' : `Selected: ${n} date${n === 1 ? '' : 's'}`
        }
        const miss = []
        const s = this.step1State
        if (s.selectedDates.length === 0) miss.push('dates')
        if (!(s.prefix || '').trim()) miss.push('name pattern')
        if (s.sharedLoc === '') miss.push('location')
        if (!s.sharedStart) miss.push('start time')
        if (!s.sharedEnd) miss.push('end time')
        return `Missing: ${miss.join(', ')}`
      }
      if (this.view === 'bulk-review') {
        if (this.rows.length > MAX_ROWS) return `Over ${MAX_ROWS}-event limit — remove ${this.rows.length - MAX_ROWS}`
        if (this.canConfirmBulk) return `Will create ${this.rows.length} event${this.rows.length === 1 ? '' : 's'}`
        const need = this.rows.filter(r => !r.name || !r.date || !r.locationId || !r.startTime || !r.endTime).length
        return `${need} row${need === 1 ? '' : 's'} need fixing — check empty cells`
      }
      return ''
    }
  },
  watch: {
    visible(val) {
      this.show = val
      if (val) this.reset()
    },
    show(val) {
      if (!val) this.$emit('dialog-closed')
    }
  },
  methods: {
    reset() {
      this.view = 'single'
      this.singleForm = emptySingleForm()
      this.step1State = emptyStep1State(computeMonthSpan(this.courseStartAt, this.courseEndAt))
      this.rows = []
      this.attempted = false
    },
    cancel() {
      this.show = false
    },
    goToSingle() {
      this.view = 'single'
      this.attempted = false
    },
    goToBulkDates() {
      this.view = 'bulk-dates'
      this.attempted = false
    },
    tryGoToReview() {
      if (!this.bulkStep1Valid) {
        this.attempted = true
        return
      }
      const s = this.step1State
      this.rows = s.selectedDates.map((d, i) => ({
        id: Math.random().toString(36).slice(2, 9),
        name: buildName(s.prefix, s.nameFormat, s.startNum, i, d),
        date: d,
        locationId: s.sharedLoc,
        startTime: s.sharedStart,
        endTime: s.sharedEnd
      }))
      this.attempted = false
      this.view = 'bulk-review'
    },
    confirmSingle() {
      if (!this.canConfirmSingle) {
        this.attempted = true
        return
      }
      const f = this.singleForm
      this.$emit('create-events', {
        events: [{
          name: f.name,
          location_id: f.location_id,
          start_at: f.start_at,
          end_at: f.end_at
        }],
        rowIds: null
      })
    },
    confirmBulk() {
      if (!this.canConfirmBulk) return
      const events = this.rows.map(r => ({
        name: r.name,
        location_id: parseInt(r.locationId, 10),
        start_at: `${r.date}T${r.startTime}:00`,
        end_at: `${r.date}T${r.endTime}:00`
      }))
      this.$emit('create-events', {
        events,
        rowIds: this.rows.map(r => r.id)
      })
    }
  }
}
</script>

<style scoped>
.ce-header__title {
  font-size: 18px;
  font-weight: 600;
  color: #303133;
  letter-spacing: -0.005em;
}
.ce-header--step {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.ce-header__step {
  font-size: 11px;
  font-weight: 600;
  color: #EAA034;
  text-transform: uppercase;
  letter-spacing: 0.6px;
}
.ce-header__subtitle {
  font-size: 13px;
  color: #909399;
}
.ce-header__progress {
  display: flex;
  gap: 4px;
  margin-top: 4px;
}
.ce-header__bar {
  flex: 1;
  height: 3px;
  border-radius: 2px;
  background: #ebeef5;
  transition: background 200ms;
}
.ce-header__bar--active { background: #EAA034; }
.ce-toggle {
  margin: 0 0 18px 0;
  padding: 12px 14px;
  background: #fafbfc;
  border: 1px solid #ebeef5;
  border-radius: 4px;
}
.ce-toggle--active {
  background: #fffaf0;
  border-color: #f0d4a8;
}
.ce-toggle label {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  user-select: none;
}
.ce-toggle input[type=checkbox] {
  width: 16px;
  height: 16px;
  accent-color: #409eff;
  cursor: pointer;
}
.ce-toggle__title {
  font-size: 14px;
  font-weight: 600;
  color: #303133;
}
.ce-toggle__hint {
  font-size: 12px;
  color: #909399;
}
.ce-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.ce-footer__status {
  font-size: 13px;
  color: #606266;
}
.ce-footer__actions {
  display: flex;
  gap: 8px;
}

/* Animate modal width as view changes size */
:deep(.el-dialog) {
  transition: width 220ms ease;
}

/* Cross-fade body content between views */
.ce-fade-enter-active,
.ce-fade-leave-active {
  transition: opacity 160ms ease;
}
.ce-fade-enter-from,
.ce-fade-leave-to {
  opacity: 0;
}
</style>

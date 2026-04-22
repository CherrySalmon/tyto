<template>
  <div :class="['cal-strip', { 'cal-strip--invalid': invalid }]">
    <div class="cal-strip__header">
      <span class="cal-strip__title">
        <span v-if="required" class="cal-strip__req">*</span>
        Dates
        <span class="cal-strip__hint">· click to toggle · scroll →</span>
      </span>
      <div class="cal-strip__actions">
        <button type="button" class="cal-strip__btn cal-strip__btn--primary" @click="addMonth">
          + Add month
        </button>
      </div>
    </div>

    <div ref="stripRef" class="cal-strip__months">
      <div v-for="i in monthCount" :key="i" class="cal-strip__month">
        <div class="cal-month">
          <div class="cal-month__title">{{ monthName(i - 1) }}</div>
          <div class="cal-month__grid">
            <div v-for="dow in weekdays" :key="dow.key" class="cal-month__dow">{{ dow.label }}</div>
            <div
              v-for="(cell, ci) in cellsFor(i - 1)"
              :key="`${i}-${ci}`"
              :class="cellClass(cell)"
              @click="toggle(cell)"
            >
              <template v-if="cell">
                {{ cell.day }}
                <div v-if="cell.isExisting && !cell.isSelected" class="cal-month__dot" />
              </template>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
const pad2 = n => String(n).padStart(2, '0')
const fmtDateISO = d => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
const sameDay = (a, b) =>
  a.getFullYear() === b.getFullYear() &&
  a.getMonth() === b.getMonth() &&
  a.getDate() === b.getDate()

export default {
  name: 'EventCalendarStrip',
  emits: ['toggle-date', 'update:monthCount'],
  props: {
    selectedDates: { type: Array, default: () => [] },
    existingDates: { type: Array, default: () => [] },
    monthCount: { type: Number, default: 2 },
    courseStartAt: { type: [String, Date], default: null },
    invalid: { type: Boolean, default: false },
    required: { type: Boolean, default: true }
  },
  data() {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    return {
      today,
      weekdays: [
        { key: 'su', label: 'S' },
        { key: 'mo', label: 'M' },
        { key: 'tu', label: 'T' },
        { key: 'we', label: 'W' },
        { key: 'th', label: 'T' },
        { key: 'fr', label: 'F' },
        { key: 'sa', label: 'S' }
      ],
      prevMonthCount: this.monthCount
    }
  },
  watch: {
    monthCount(val) {
      if (val > this.prevMonthCount && this.$refs.stripRef) {
        const el = this.$refs.stripRef
        this.$nextTick(() => {
          requestAnimationFrame(() => el.scrollTo({ left: el.scrollWidth, behavior: 'smooth' }))
        })
      }
      this.prevMonthCount = val
    }
  },
  computed: {
    anchor() {
      const s = this.courseStartAt ? new Date(this.courseStartAt) : null
      const ref = s && !isNaN(s.getTime()) ? s : this.today
      return new Date(ref.getFullYear(), ref.getMonth(), 1)
    }
  },
  methods: {
    baseFor(offset) {
      return new Date(this.anchor.getFullYear(), this.anchor.getMonth() + offset, 1)
    },
    monthName(offset) {
      return this.baseFor(offset).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
    },
    cellsFor(offset) {
      const base = this.baseFor(offset)
      const year = base.getFullYear()
      const month = base.getMonth()
      const firstDow = new Date(year, month, 1).getDay()
      const daysInMonth = new Date(year, month + 1, 0).getDate()
      const cells = []
      for (let i = 0; i < firstDow; i++) cells.push(null)
      for (let d = 1; d <= daysInMonth; d++) {
        const date = new Date(year, month, d)
        const iso = fmtDateISO(date)
        cells.push({
          date,
          iso,
          day: d,
          isSelected: this.selectedDates.includes(iso),
          isToday: sameDay(date, this.today),
          isExisting: this.existingDates.includes(iso),
          isWeekend: date.getDay() === 0 || date.getDay() === 6,
          isPast: date < this.today
        })
      }
      while (cells.length % 7 !== 0) cells.push(null)
      return cells
    },
    cellClass(cell) {
      if (!cell) return 'cal-month__cell cal-month__cell--empty'
      const cls = ['cal-month__cell']
      if (cell.isPast) cls.push('cal-month__cell--past')
      if (cell.isSelected) cls.push('cal-month__cell--selected')
      else if (cell.isExisting) cls.push('cal-month__cell--existing')
      if (cell.isToday && !cell.isSelected) cls.push('cal-month__cell--today')
      if (cell.isWeekend && !cell.isSelected && !cell.isPast) cls.push('cal-month__cell--weekend')
      return cls.join(' ')
    },
    toggle(cell) {
      if (!cell) return
      this.$emit('toggle-date', cell.iso)
    },
    addMonth() {
      this.$emit('update:monthCount', this.monthCount + 1)
    }
  }
}
</script>

<style scoped>
.cal-strip {
  padding: 14px;
  background: #fff;
  border: 1px solid #ebeef5;
  border-radius: 4px;
}
.cal-strip--invalid {
  border-color: #f56c6c;
  background: #fef6f6;
}
.cal-strip__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}
.cal-strip__title {
  font-size: 12px;
  font-weight: 700;
  color: #606266;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.cal-strip__req {
  color: #f56c6c;
  font-weight: 400;
  margin-right: 4px;
}
.cal-strip__hint {
  font-weight: 400;
  color: #909399;
  margin-left: 6px;
  text-transform: none;
  letter-spacing: 0;
}
.cal-strip__actions {
  display: flex;
  gap: 6px;
}
.cal-strip__btn {
  font-size: 12px;
  border-radius: 3px;
  padding: 4px 10px;
  cursor: pointer;
  font-family: inherit;
  background: #fff;
}
.cal-strip__btn--ghost {
  color: #909399;
  background: transparent;
  border: 1px solid #dcdfe6;
  font-weight: 500;
}
.cal-strip__btn--primary {
  color: #409eff;
  border: 1px solid #409eff;
  font-weight: 600;
}
.cal-strip__months {
  display: flex;
  gap: 10px;
  margin-bottom: 10px;
  overflow-x: auto;
  overflow-y: hidden;
  padding-bottom: 8px;
  scroll-behavior: smooth;
  scrollbar-width: thin;
}
.cal-strip__month {
  flex: 0 0 calc(50% - 5px);
  min-width: 260px;
}
.cal-month {
  background: #fff;
  border: 1px solid #e4e7ed;
  border-radius: 4px;
  padding: 10px;
}
.cal-month__title {
  text-align: center;
  font-weight: 600;
  font-size: 13px;
  color: #606266;
  margin-bottom: 6px;
}
.cal-month__grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 1px;
}
.cal-month__dow {
  text-align: center;
  font-size: 10px;
  color: #909399;
  padding: 3px 0;
  font-weight: 600;
}
.cal-month__cell {
  text-align: center;
  padding: 6px 0;
  font-size: 12px;
  border-radius: 3px;
  cursor: pointer;
  position: relative;
  transition: background 120ms;
  color: #303133;
  border: 1px solid transparent;
}
.cal-month__cell:hover:not(.cal-month__cell--selected):not(.cal-month__cell--empty) {
  background: #f5f7fa;
}
.cal-month__cell--empty {
  cursor: default;
}
.cal-month__cell--past:not(.cal-month__cell--selected) {
  color: #c0c4cc;
}
.cal-month__cell--weekend {
  color: #c0c4cc;
}
.cal-month__cell--today {
  font-weight: 700;
  border-color: #EAA034;
}
.cal-month__cell--existing {
  background: #fdf6ec;
}
.cal-month__cell--selected {
  background: #EAA034;
  color: #fff;
  font-weight: 600;
}
.cal-month__dot {
  position: absolute;
  bottom: 1px;
  left: 50%;
  transform: translateX(-50%);
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: #e6a23c;
}
</style>

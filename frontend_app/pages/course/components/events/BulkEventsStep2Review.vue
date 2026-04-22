<template>
  <div class="bulk-step2">
    <!-- Toolbar -->
    <div class="toolbar">
      <div class="toolbar__status">
        <b>{{ rows.length }}</b> event{{ rows.length === 1 ? '' : 's' }} ready
        <span v-if="rows.length > maxRows" class="toolbar__over">
          — over {{ maxRows }} max, remove {{ rows.length - maxRows }}
        </span>
        <span v-if="conflictCount > 0" class="toolbar__warn">
          ⚠ {{ conflictCount }} same-location conflict{{ conflictCount === 1 ? '' : 's' }}
        </span>
      </div>
      <div class="toolbar__actions">
        <button type="button" class="fill-btn" @click="fillDown('locationId')">Fill location ↓</button>
        <button type="button" class="fill-btn" @click="fillDown('startTime')">Fill start ↓</button>
        <button type="button" class="fill-btn" @click="fillDown('endTime')">Fill end ↓</button>
      </div>
    </div>

    <!-- Grid -->
    <div class="grid-wrap">
      <table class="grid">
        <thead>
          <tr>
            <th class="grid__th" style="width: 32px;">#</th>
            <th class="grid__th" style="width: 220px;">Name</th>
            <th class="grid__th" style="width: 150px;">Date</th>
            <th class="grid__th" style="width: 200px;">Location</th>
            <th class="grid__th" style="width: 90px;">Start</th>
            <th class="grid__th" style="width: 90px;">End</th>
            <th class="grid__th" style="width: 60px;"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(row, i) in rows"
            :key="row.id"
            :class="[
              'grid__tr',
              { 'grid__tr--even': i % 2 === 0,
                'grid__tr--conflict': conflictIds.has(row.id),
                'grid__tr--error': !!errors[row.id] }
            ]"
          >
            <td class="grid__td grid__td--num">{{ i + 1 }}</td>
            <td class="grid__td">
              <input
                class="cell cell--text"
                :value="row.name"
                @input="update(row.id, { name: $event.target.value })"
              />
            </td>
            <td class="grid__td">
              <input
                class="cell cell--text"
                type="date"
                :value="row.date"
                @input="update(row.id, { date: $event.target.value })"
              />
            </td>
            <td class="grid__td">
              <select
                class="cell cell--select"
                :value="row.locationId"
                @change="update(row.id, { locationId: $event.target.value })"
              >
                <option value="">—</option>
                <option v-for="loc in locations" :key="loc.id" :value="loc.id">{{ loc.name }}</option>
              </select>
            </td>
            <td class="grid__td">
              <TimeInput
                :model-value="row.startTime"
                width="100%"
                @update:modelValue="v => update(row.id, { startTime: v })"
              />
            </td>
            <td class="grid__td">
              <TimeInput
                :model-value="row.endTime"
                width="100%"
                @update:modelValue="v => update(row.id, { endTime: v })"
              />
            </td>
            <td class="grid__td grid__td--actions">
              <span
                v-if="conflictIds.has(row.id)"
                class="grid__warn"
                :title="conflictReason(row.id)"
              >⚠</span>
              <button type="button" class="icon-btn icon-btn--danger" title="Remove" @click="remove(row.id)">×</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="rows.length === 0" class="grid__empty">
        No events. Add a row manually, or cancel and pick dates.
      </div>
      <div v-if="hasErrors" class="grid__errors">
        <div v-for="row in errorRows" :key="row.id" class="grid__error-line">
          <b>Row {{ rowIndex(row.id) + 1 }}:</b> {{ errors[row.id] }}
        </div>
      </div>
    </div>

    <div class="add-row">
      <button type="button" class="add-row__btn" @click="addRow">+ Add event</button>
    </div>
  </div>
</template>

<script>
import TimeInput from './TimeInput.vue'

const pad2 = n => String(n).padStart(2, '0')
const fmtDateISO = d => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`

function addDays(iso, n) {
  const d = new Date(`${iso}T00:00`)
  d.setDate(d.getDate() + n)
  return fmtDateISO(d)
}

function detectConflicts(rows) {
  const conflicts = []
  for (let i = 0; i < rows.length; i++) {
    for (let j = i + 1; j < rows.length; j++) {
      const a = rows[i]
      const b = rows[j]
      if (a.date === b.date && a.locationId && String(a.locationId) === String(b.locationId)) {
        const existing = conflicts.find(c => c.ids.includes(a.id) || c.ids.includes(b.id))
        if (existing) {
          if (!existing.ids.includes(a.id)) existing.ids.push(a.id)
          if (!existing.ids.includes(b.id)) existing.ids.push(b.id)
        } else {
          conflicts.push({ ids: [a.id, b.id], reason: `Same location on ${a.date}` })
        }
      }
    }
  }
  return conflicts
}

export default {
  name: 'BulkEventsStep2Review',
  components: { TimeInput },
  emits: ['update:rows'],
  props: {
    modelRows: { type: Array, required: true },
    locations: { type: Array, default: () => [] },
    errors: { type: Object, default: () => ({}) },
    maxRows: { type: Number, default: 100 }
  },
  computed: {
    rows: {
      get() { return this.modelRows },
      set(val) { this.$emit('update:rows', val) }
    },
    conflicts() { return detectConflicts(this.rows) },
    conflictIds() {
      const set = new Set()
      this.conflicts.forEach(c => c.ids.forEach(id => set.add(id)))
      return set
    },
    conflictCount() { return this.conflicts.length },
    hasErrors() { return Object.keys(this.errors).length > 0 },
    errorRows() {
      return this.rows.filter(r => this.errors[r.id])
    }
  },
  methods: {
    update(id, patch) {
      this.rows = this.rows.map(r => (r.id === id ? { ...r, ...patch } : r))
    },
    remove(id) {
      this.rows = this.rows.filter(r => r.id !== id)
    },
    addRow() {
      const last = this.rows[this.rows.length - 1]
      const nextDate = last ? addDays(last.date, 7) : fmtDateISO(new Date())
      this.rows = [
        ...this.rows,
        {
          id: Math.random().toString(36).slice(2, 9),
          name: '',
          date: nextDate,
          locationId: last?.locationId || '',
          startTime: last?.startTime || '',
          endTime: last?.endTime || ''
        }
      ]
    },
    fillDown(key) {
      if (this.rows.length === 0) return
      const v = this.rows[0][key]
      this.rows = this.rows.map(r => ({ ...r, [key]: v }))
    },
    conflictReason(id) {
      const c = this.conflicts.find(x => x.ids.includes(id))
      return c ? c.reason : ''
    },
    rowIndex(id) {
      return this.rows.findIndex(r => r.id === id)
    }
  }
}
</script>

<style scoped>
.bulk-step2 {
  display: flex;
  flex-direction: column;
  gap: 14px;
  min-height: 0;
}
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  flex-wrap: wrap;
}
.toolbar__status {
  font-size: 13px;
  color: #606266;
}
.toolbar__status b { color: #303133; }
.toolbar__over {
  margin-left: 10px;
  color: #c45656;
  font-weight: 500;
}
.toolbar__warn {
  margin-left: 10px;
  color: #b88230;
  background: #fdf6ec;
  padding: 2px 8px;
  border-radius: 10px;
  font-weight: 500;
  font-size: 12px;
}
.toolbar__actions {
  display: flex;
  gap: 6px;
}
.fill-btn {
  background: #fff;
  border: 1px solid #dcdfe6;
  color: #606266;
  padding: 3px 9px;
  border-radius: 4px;
  font-size: 11px;
  cursor: pointer;
  font-family: inherit;
}
.grid-wrap {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  border: 1px solid #ebeef5;
  border-radius: 4px;
}
.grid {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.grid__th {
  text-align: left;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: #909399;
  padding: 10px 8px;
  border-bottom: 1px solid #ebeef5;
  background: #fafbfc;
  position: sticky;
  top: 0;
  z-index: 1;
  white-space: nowrap;
}
.grid__tr--even { background: #fff; }
.grid__tr:not(.grid__tr--even) { background: #fafbfc; }
.grid__tr--conflict { background: #fdf6ec !important; }
.grid__tr--error { background: #fef6f6 !important; }
.grid__td {
  padding: 4px 6px;
  border-bottom: 1px solid #f2f4f7;
  vertical-align: middle;
}
.grid__td--num {
  color: #909399;
  font-size: 12px;
}
.grid__td--actions {
  text-align: right;
  white-space: nowrap;
}
.grid__warn {
  color: #b88230;
  margin-right: 4px;
  cursor: help;
}
.cell {
  width: 100%;
  padding: 6px 8px;
  font-size: 13px;
  border: 1px solid transparent;
  border-radius: 3px;
  outline: none;
  background: transparent;
  font-family: inherit;
  color: #303133;
}
.cell:focus {
  border-color: #409eff;
  background: #fff;
}
.cell--select { cursor: pointer; }
.icon-btn {
  background: transparent;
  border: none;
  cursor: pointer;
  color: #909399;
  padding: 2px 6px;
  font-size: 14px;
  line-height: 1;
  border-radius: 3px;
  font-family: inherit;
}
.icon-btn--danger { color: #f56c6c; }
.grid__empty {
  padding: 32px 20px;
  text-align: center;
  color: #909399;
  font-size: 13px;
}
.grid__errors {
  padding: 10px 14px;
  background: #fef6f6;
  border-top: 1px solid #fbc4c4;
  font-size: 12px;
  color: #c45656;
}
.grid__error-line { margin-bottom: 4px; }
.add-row { margin-top: 4px; }
.add-row__btn {
  background: #fff;
  border: 1px dashed #409eff;
  color: #409eff;
  padding: 5px 12px;
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  font-family: inherit;
  font-weight: 500;
}
</style>

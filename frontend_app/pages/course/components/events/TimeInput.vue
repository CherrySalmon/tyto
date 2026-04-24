<template>
  <input
    type="text"
    inputmode="numeric"
    :value="local"
    placeholder="--:--"
    :class="['time-input', { 'time-input--cell': isCell, 'time-input--invalid': invalid }]"
    :style="widthStyle"
    @input="onInput"
    @blur="onBlur"
  />
</template>

<script>
export default {
  name: 'TimeInput',
  emits: ['update:modelValue'],
  props: {
    modelValue: { type: String, default: '' },
    invalid: { type: Boolean, default: false },
    width: { type: [Number, String], default: 140 }
  },
  data() {
    return {
      local: this.modelValue || ''
    }
  },
  computed: {
    isCell() {
      return this.width === '100%'
    },
    widthStyle() {
      if (this.isCell) return { width: '100%' }
      const w = typeof this.width === 'number' ? `${this.width}px` : this.width
      return { width: w }
    }
  },
  watch: {
    modelValue(val) {
      this.local = val || ''
    }
  },
  methods: {
    format(raw) {
      const d = String(raw || '').replace(/\D/g, '').slice(0, 4)
      if (d.length <= 2) return d
      return `${d.slice(0, 2)}:${d.slice(2)}`
    },
    onInput(e) {
      this.local = this.format(e.target.value)
    },
    onBlur(e) {
      const raw = e.target.value
      if (!raw) {
        this.$emit('update:modelValue', '')
        return
      }
      const m = raw.match(/^(\d{1,2}):?(\d{0,2})$/)
      if (!m) {
        this.$emit('update:modelValue', '')
        return
      }
      let h = parseInt(m[1], 10)
      let mm = parseInt(m[2] || '0', 10)
      if (isNaN(h) || h > 23) h = 0
      if (isNaN(mm) || mm > 59) mm = 0
      const out = `${String(h).padStart(2, '0')}:${String(mm).padStart(2, '0')}`
      this.local = out
      this.$emit('update:modelValue', out)
    }
  }
}
</script>

<style scoped>
.time-input {
  padding: 6px 11px;
  font-size: 14px;
  border: 1px solid #dcdfe6;
  border-radius: 4px;
  outline: none;
  color: #303133;
  font-family: inherit;
  font-variant-numeric: tabular-nums;
  transition: border 120ms;
}
.time-input:focus {
  border-color: #409eff;
}
.time-input--invalid {
  border-color: #f56c6c;
  background: #fef6f6;
}
.time-input--cell {
  padding: 6px 8px;
  font-size: 13px;
  border: 1px solid transparent;
  border-radius: 3px;
  background: transparent;
}
.time-input--cell:focus {
  border-color: #409eff;
  background: #fff;
}
</style>

<template>
  <div class="qp">
    <button
      v-for="(b, i) in buttons"
      :key="i"
      type="button"
      class="qp__chip"
      @click="$emit('apply', { dows: b.dows })"
    >{{ b.label }}</button>
  </div>
</template>

<script>
export default {
  name: 'QuickPickChips',
  emits: ['apply'],
  data() {
    return {
      buttons: [
        { label: 'Every Mon', dows: [1] },
        { label: 'Every Wed', dows: [3] },
        { label: 'Every Fri', dows: [5] },
        { label: 'Mon + Wed', dows: [1, 3] },
        { label: 'Tue + Thu', dows: [2, 4] }
      ]
    }
  }
}
</script>

<style scoped>
.qp {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.qp__chip {
  background: #fff;
  border: 1px dashed #c0c4cc;
  border-radius: 14px;
  padding: 3px 10px;
  font-size: 11px;
  color: #606266;
  cursor: pointer;
  font-family: inherit;
  transition: border-color 120ms, color 120ms;
}
.qp__chip:hover {
  border-color: #409eff;
  color: #409eff;
}
</style>

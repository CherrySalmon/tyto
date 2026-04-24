<template>
  <div class="assignments-card-container course-card-container">
    <div class="course-content-title">Assignments</div>

    <el-card v-if="canManage" class="assignment-item" shadow="hover" @click.stop="$emit('create-assignment')">
      <h3>Create Assignment</h3>
      <el-icon :size="24" style="margin-top: 10px;"><DocumentAdd /></el-icon>
    </el-card>

    <el-card
      v-for="assignment in assignments"
      :key="assignment.id"
      class="assignment-item"
      shadow="always"
      style="background-color: #f2f2f2"
      @click="$emit('view-assignment', assignment.id)"
    >
      <div>
        <h3>{{ assignment.title }}</h3>
        <el-tag v-if="canManage" :type="statusTagType(assignment.status)" size="small">
          {{ assignment.status }}
        </el-tag>
        <p v-if="assignment.due_at" class="assignment-due">
          Due: {{ formatDateTime(assignment.due_at) }}
        </p>
        <p v-else class="assignment-due">No due date</p>
        <div v-if="canManage" class="assignment-actions" @click.stop>
          <el-icon :size="18" @click="$emit('edit-assignment', assignment.id)">
            <Edit />
          </el-icon>
          <el-icon
            v-if="assignment.status === 'draft'"
            :size="18"
            @click="$emit('publish-assignment', assignment.id)"
            style="margin-left: 10px;"
            title="Publish"
          >
            <Promotion />
          </el-icon>
          <el-icon
            v-if="assignment.status === 'published' && canUnpublish(assignment)"
            :size="18"
            @click="$emit('unpublish-assignment', assignment.id)"
            style="margin-left: 10px;"
            title="Unpublish (return to draft)"
          >
            <Hide />
          </el-icon>
          <el-icon
            v-if="canDelete(assignment)"
            :size="18"
            @click="$emit('delete-assignment', assignment.id)"
            style="margin-left: 10px;"
          >
            <Delete />
          </el-icon>
        </div>
      </div>
    </el-card>
  </div>
</template>

<script>
import { formatLocalDateTime } from '../../../lib/dates'

export default {
  emits: ['create-assignment', 'edit-assignment', 'delete-assignment', 'publish-assignment', 'unpublish-assignment', 'view-assignment'],
  props: {
    course: Object,
    assignments: Array,
    canManage: {
      type: Boolean,
      default: true
    }
  },
  methods: {
    formatDateTime(utcStr) {
      return formatLocalDateTime(utcStr)
    },
    statusTagType(status) {
      switch (status) {
        case 'draft': return 'warning'
        case 'published': return 'success'
        case 'disabled': return 'info'
        default: return ''
      }
    },
    // Treat a missing `policies` object as permissive (older responses),
    // but an explicit `false` as a denial from the backend.
    canUnpublish(assignment) {
      return assignment?.policies?.can_unpublish !== false
    },
    canDelete(assignment) {
      return assignment?.policies?.can_delete !== false
    }
  }
}
</script>

<style scoped>
.assignments-card-container {
  display: flex;
  justify-content: flex-start;
  flex-wrap: wrap;
}

@media (max-width: 768px) {
  .assignments-card-container {
    justify-content: center;
  }
}

.assignment-item {
  width: 20%;
  min-width: 200px;
  margin: 10px;
  padding: 0px;
  cursor: pointer;
  text-align: center;
  font-size: 14px;
  line-height: 2.5rem;
}

.assignment-due {
  font-size: 0.85rem;
  color: #666;
  margin: 5px 0;
}

.assignment-actions {
  margin-top: 10px;
}
</style>

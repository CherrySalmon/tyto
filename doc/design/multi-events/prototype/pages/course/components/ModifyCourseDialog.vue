<template>
    <el-dialog
      title="Modify Course"
      v-model="showModifyCourseDialog"
      @close="onDialogClose"
      width="100%" :modalAppendToBody="false"
      >
      <el-form :model="localCourseForm" ref="courseForm" label-width="auto">
        <el-form-item label="Name">
          <el-input v-model="localCourseForm.name" style="width:95%;"></el-input>
        </el-form-item>
        <el-form-item label="Start Time">
          <el-date-picker
            v-model="localCourseForm.start_at"
            type="datetime"
            placeholder="Select start time"
            style="width:95%;"
            time-format="HH:mm">
          </el-date-picker>
        </el-form-item>
        <el-form-item label="End Time">
          <el-date-picker
            v-model="localCourseForm.end_at"
            type="datetime"
            placeholder="Select start time"
            style="width:95%;"
            time-format="HH:mm">
          </el-date-picker>
        </el-form-item>
      </el-form>
      <span slot="footer" class="dialog-footer">
        <el-button @click="onDialogClose">Cancel</el-button>
        <el-button type="primary" @click="submitForm">Confirm</el-button>
      </span>
    </el-dialog>
  </template>
  
  <script>
  export default {
    name: 'ModifyCourseDialog',
    emits: ['dialog-closed', 'update-course'],
    props: {
      courseForm: {
        type: Object,
        default: () => ({})
      },
      visible: Boolean
    },
    data() {
      return {
        localCourseForm: this.courseForm,
        showModifyCourseDialog: false
      };
    },
    watch: {
      courseForm: {
        deep: true,
        handler(newVal) {
          this.localCourseForm = { ...newVal };
        }
      },
      visible: {
        handler(newVal) {
            this.showModifyCourseDialog = newVal
        }
      }
    },
    methods: {
      submitForm() {
        this.$refs.courseForm.validate((valid) => {
          if (valid) {
            this.$emit('update-course', this.localCourseForm);
            this.showModifyCourseDialog = false;
          } else {
            console.log('error submit!!');
            return false;
          }
        });
      },
      onDialogClose() {
        this.showModifyCourseDialog = false;
        this.$emit('dialog-closed');
      }
    }
  }
  </script>
  
  <style scoped>
  .dialog-footer {
    text-align: right;
  }
  </style>
  
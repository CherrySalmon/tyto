"use strict";
/*
 * ATTENTION: The "eval" devtool has been used (maybe by default in mode: "development").
 * This devtool is neither made for production nor for readable output files.
 * It uses "eval()" calls to create a separate source file in the browser devtools.
 * If you are trying to read the output file, select a different devtool (https://webpack.js.org/configuration/devtool/)
 * or disable the default devtool with "devtool: false".
 * If you are looking for production-ready output files, see mode: "production" (https://webpack.js.org/configuration/mode/).
 */
self["webpackHotUpdateminimal_vue_webpack"]("main",{

/***/ "./node_modules/unplugin/dist/webpack/loaders/transform.js?unpluginName=unplugin-vue-components!./node_modules/unplugin/dist/webpack/loaders/transform.js?unpluginName=unplugin-auto-import!./node_modules/vue-loader/dist/index.js??ruleSet[1].rules[6].use[0]!./frontend_app/pages/course/AllCourse.vue?vue&type=script&lang=js":
/*!****************************************************************************************************************************************************************************************************************************************************************************************************************************************!*\
  !*** ./node_modules/unplugin/dist/webpack/loaders/transform.js?unpluginName=unplugin-vue-components!./node_modules/unplugin/dist/webpack/loaders/transform.js?unpluginName=unplugin-auto-import!./node_modules/vue-loader/dist/index.js??ruleSet[1].rules[6].use[0]!./frontend_app/pages/course/AllCourse.vue?vue&type=script&lang=js ***!
  \****************************************************************************************************************************************************************************************************************************************************************************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

eval("__webpack_require__.r(__webpack_exports__);\n/* harmony export */ __webpack_require__.d(__webpack_exports__, {\n/* harmony export */   \"default\": () => (__WEBPACK_DEFAULT_EXPORT__)\n/* harmony export */ });\n/* harmony import */ var axios__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! axios */ \"./node_modules/axios/lib/axios.js\");\n/* harmony import */ var _lib_cookieManager__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../../lib/cookieManager */ \"./frontend_app/lib/cookieManager.js\");\n/* harmony import */ var element_plus__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! element-plus */ \"./node_modules/element-plus/es/components/notification/index.mjs\");\n/* harmony import */ var element_plus_es__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! element-plus/es */ \"./node_modules/element-plus/es/components/loading/index.mjs\");\n/* harmony import */ var element_plus_es__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! element-plus/es */ \"./node_modules/element-plus/es/components/message-box/index.mjs\");\n/* harmony import */ var element_plus_es_components_base_style_css__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! element-plus/es/components/base/style/css */ \"./node_modules/element-plus/es/components/base/style/css.mjs\");\n/* harmony import */ var element_plus_es_components_loading_style_css__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! element-plus/es/components/loading/style/css */ \"./node_modules/element-plus/es/components/loading/style/css.mjs\");\n/* harmony import */ var element_plus_es_components_message_box_style_css__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! element-plus/es/components/message-box/style/css */ \"./node_modules/element-plus/es/components/message-box/style/css.mjs\");\n/* unplugin-vue-components disabled */\n\n\n\n\n\n\n\n\n\n\n/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = ({\n  name: 'Courses',\n\n  data() {\n    return {\n      rules: {\n        name: [\n          { required: true, message: 'Please input course name', trigger: 'blur' }\n        ]\n      },\n      features: {\n        admin: 'manage accounts',\n        creator: 'create courses',\n        member: 'mark attendance'\n      },\n      courses: [],\n      account: {\n        roles: [],\n        credential: ''\n      },\n      showCreateCourseDialog: false,\n      createCourseForm: {\n        name: '',\n        start_at: '',\n        end_at: '',\n        logo: '',\n      },\n      events: {},\n    };\n  },\n  created() {\n    this.accountCredential = _lib_cookieManager__WEBPACK_IMPORTED_MODULE_0__[\"default\"].getCookie('account_credential');\n    this.account = _lib_cookieManager__WEBPACK_IMPORTED_MODULE_0__[\"default\"].getAccount()\n    if (this.account) {\n      this.fetchCourses()\n      this.fetchEventData()\n    }\n  },\n  methods: {\n    async fetchEventData() { // Mark the method as async\n        try {\n            const response = await axios__WEBPACK_IMPORTED_MODULE_4__[\"default\"].get(`/api/current_event/`, {\n                headers: {\n                    Authorization: `Bearer ${this.accountCredential}`,\n                },\n            });\n\n            this.events = await Promise.all(response.data.data.map(async (event) => {\n                // Use getCourseName to fetch the course name asynchronously\n                let course_name = await this.getCourseName(event.course_id)\n                let location_name = await this.getLocationName(event)\n                let isAttendanceExisted = await this.findAttendance(event)\n                return {\n                    ...event,\n                    course_name: course_name,\n                    location_name: location_name,\n                    isAttendanceExisted: isAttendanceExisted,\n                };\n            }));\n        } catch (error) {\n            console.error('Error fetching event data:', error);\n        }\n    },\n    getCourseName(course_id) {\n        return axios__WEBPACK_IMPORTED_MODULE_4__[\"default\"].get(`/api/course/${course_id}`, {\n            headers: {\n                Authorization: `Bearer ${this.accountCredential}`,\n            },\n        }).then(response => response.data.data.name) // Assuming the response has this structure\n        .catch(error => {\n            console.error('Error fetching course name:', error);\n            return 'Error fetching course name'; // Provide a fallback or error message\n        });\n    },\n    getLocationName(event) {\n        return axios__WEBPACK_IMPORTED_MODULE_4__[\"default\"].get(`/api/course/${event.course_id}/location/${event.location_id}`, {\n            headers: {\n                Authorization: `Bearer ${this.accountCredential}`,\n            },\n        }).then(response => response.data.data.name) // Assuming the response has this structure\n        .catch(error => {\n            console.error('Error fetching location name:', error);\n            return 'Error fetching location name'; // Provide a fallback or error message\n        });\n    },\n    getLocation(event) {\n        console.log(\"start getting location\");\n        // Start the loading screen\n        const loading = element_plus_es__WEBPACK_IMPORTED_MODULE_5__.ElLoading.service({\n            lock: true,\n            text: 'Loading',\n            background: 'rgba(0, 0, 0, 0.7)',\n        });\n        if (navigator.geolocation) {\n            navigator.geolocation.getCurrentPosition(\n                position => this.showPosition(position, loading, event),\n                error => this.showError(error, loading)\n            );\n        } else {\n            this.locationText = \"Geolocation is not supported by this browser.\";\n        }\n    },\n    showPosition(position, loading, event) {\n        this.locationText = `Latitude: ${position.coords.latitude}, Longitude: ${position.coords.longitude}, Accuracy: ${position.coords.accuracy}`;\n\n        this.latitude = position.coords.latitude;\n        this.longitude = position.coords.longitude;\n\n        const course_id = event.course_id;\n        const location_id = event.location_id;\n\n        axios__WEBPACK_IMPORTED_MODULE_4__[\"default\"].get(`/api/course/${course_id}/location/${location_id}`, {\n            headers: {\n                Authorization: `Bearer ${this.accountCredential}`,\n            },\n        }).then(response => {\n            console.log('Event Data Fetched Successfully:', response.data.data);\n            this.location = response.data.data;\n            this.isEventDataFetched = true;\n\n            let range = 1.0005\n            const minLat = this.location.latitude - range;\n            const maxLat = this.location.latitude + range;\n            const minLng = this.location.longitude - range\n            const maxLng = this.location.longitude + range;\n\n            // Check if the current position is within the range\n            if (this.latitude >= minLat && this.latitude <= maxLat && this.longitude >= minLng && this.longitude <= maxLng) {\n                // Call your API if within the range\n                this.postAttendance(loading, event);\n            } else {\n                element_plus_es__WEBPACK_IMPORTED_MODULE_6__.ElMessageBox.alert('You are not in the right location', 'Failed', {\n                    confirmButtonText: 'OK',\n                    type: 'error',\n                })\n                loading.close();\n            }\n        }).catch(error => {\n            console.error('Error fetching event:', error);\n        });\n    },\n    showError(error) {\n        switch (error.code) {\n            case error.PERMISSION_DENIED:\n                this.errMessage = \"User denied the request for Geolocation.\";\n                break;\n            case error.POSITION_UNAVAILABLE:\n                this.errMessage = \"Location information is unavailable.\";\n                break;\n            case error.TIMEOUT:\n                this.errMessage = \"The request to get user location timed out.\";\n                break;\n            default:\n                this.errMessage = \"An unknown error occurred.\";\n                break;\n        }\n    },\n    postAttendance(loading, event) {\n        // Use your actual course ID here\n        const courseId = event.course_id; // Example course ID\n        axios__WEBPACK_IMPORTED_MODULE_4__[\"default\"].post(`/api/course/${courseId}/attendance`, {\n            // Include any required data here\n            event_id: event.id,\n            name: event.name,\n            latitude: this.latitude,\n            longitude: this.longitude,\n        }, {\n            headers: {\n                Authorization: `Bearer ${this.accountCredential}`,\n            }\n        })\n            .then(response => {\n                // Handle success\n                console.log('Attendance recorded successfully', response.data);\n                this.updateEventAttendanceStatus(event.id, true);\n                element_plus_es__WEBPACK_IMPORTED_MODULE_6__.ElMessageBox.alert('Attendance recorded successfully', 'Success', {\n                    confirmButtonText: 'OK',\n                    type: 'success',\n                })\n            })\n            .catch(error => {\n                // Handle error\n                console.error('Error recording attendance', error);\n                this.updateEventAttendanceStatus(event.id, true);\n                element_plus_es__WEBPACK_IMPORTED_MODULE_6__.ElMessageBox.alert('Attendance has already recorded', 'Warning', {\n                    confirmButtonText: 'OK',\n                    type: 'warning',\n                })\n            }).finally(() => {\n                loading.close();\n            });\n    },\n    findAttendance(event) {\n        // Return a new promise that resolves with the boolean result\n        return new Promise((resolve, reject) => {\n            axios__WEBPACK_IMPORTED_MODULE_4__[\"default\"].get(`/api/course/${event.course_id}/attendance`, {\n                headers: {\n                    Authorization: `Bearer ${this.accountCredential}`,\n                },\n            }).then(response => {\n                const accountId = this.account.id; // Ensure this is set correctly\n                const eventId = event.id;\n                const matchingAttendances = response.data.data.filter(attendance => \n                    parseInt(attendance.account_id) == accountId && parseInt(attendance.event_id) == eventId\n                );\n\n                // Resolve the promise with true if any attendances match, otherwise false\n                resolve(matchingAttendances.length > 0);\n            }).catch(error => {\n                console.error('Error fetching attendance data:', error);\n                // Reject the promise in case of an error\n                reject(error);\n            });\n        });\n    },\n\n    updateEventAttendanceStatus(eventId, status) {\n        const eventIndex = this.events.findIndex(event => event.id === eventId);\n        if (eventIndex !== -1) {\n            // Vue 2 reactivity caveat workaround\n            // this.$set(this.events[eventIndex], 'isAttendanceExisted', status);\n            // For Vue 3, you can directly assign the value:\n            this.events[eventIndex].isAttendanceExisted = status;\n        }\n    },\n    getFeatures(roles) {\n      let features = roles.map((role) => {\n        return this.features[role]\n      })\n      return features.join(', ')\n    },\n    changeRoute(route) {\n      this.$router.push(route)\n    },\n    deleteCourse(course_id) {\n      axios__WEBPACK_IMPORTED_MODULE_4__[\"default\"].delete('api/course/'+course_id, {\n        headers: {\n          Authorization: `Bearer ${this.account.credential}`,\n        },\n      }).then(response => {\n        (0,element_plus__WEBPACK_IMPORTED_MODULE_7__.ElNotification)({\n          title: 'Success',\n          message: 'Delete success!',\n          type: 'success',\n        })\n        this.fetchCourses()\n      }).catch(error => {\n        console.error('Error fetching courses:', error);\n        (0,element_plus__WEBPACK_IMPORTED_MODULE_7__.ElNotification)({\n          title: 'Error',\n          message: error.message,\n          type: 'error',\n        })\n      });\n    },\n    fetchCourses() {\n      axios__WEBPACK_IMPORTED_MODULE_4__[\"default\"].get('api/course', {\n        headers: {\n          Authorization: `Bearer ${this.account.credential}`,\n        },\n      }).then(response => {\n        this.courses = response.data.data;\n      }).catch(error => {\n        console.error('Error fetching courses:', error);\n      });\n    },\n    submitForm(formName) {\n      this.$refs[formName].validate((valid) => {\n        if (valid) {\n          this.createCourse()\n        } else {\n          return false;\n        }\n      });\n    },\n    resetForm(formName) {\n      this.$refs[formName].resetFields();\n    },\n    closeForm(formName) {\n      this.$refs[formName].resetFields();\n      this.showCreateCourseDialog = false;\n    },\n    createCourse() {\n      axios__WEBPACK_IMPORTED_MODULE_4__[\"default\"].post('api/course', this.createCourseForm, {\n        headers: {\n          Authorization: `Bearer ${this.account.credential}`,\n        },\n      }).then(() => {\n        this.showCreateCourseDialog = false;\n        this.fetchCourses(); // Refresh the list after adding\n      }).catch(error => {\n        console.error('Error creating course:', error);\n      });\n    },\n  },\n});\n\n\n//# sourceURL=webpack://minimal-vue-webpack/./frontend_app/pages/course/AllCourse.vue?./node_modules/unplugin/dist/webpack/loaders/transform.js?unpluginName=unplugin-vue-components!./node_modules/unplugin/dist/webpack/loaders/transform.js?unpluginName=unplugin-auto-import!./node_modules/vue-loader/dist/index.js??ruleSet%5B1%5D.rules%5B6%5D.use%5B0%5D");

/***/ })

},
/******/ function(__webpack_require__) { // webpackRuntimeModules
/******/ /* webpack/runtime/getFullHash */
/******/ (() => {
/******/ 	__webpack_require__.h = () => ("ce992e1dce110029a04b")
/******/ })();
/******/ 
/******/ }
);
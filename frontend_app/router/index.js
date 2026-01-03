import { createRouter, createWebHistory } from 'vue-router';
import LoginPage from '../pages/Login.vue';
import ManageAccount from '../pages/ManageAccount.vue';
import Course from '../pages/course/index.vue';
import AllCourses from '../pages/course/AllCourse.vue'
import SingleCourse from '../pages/course/SingleCourse.vue'
import ManageCourse from '../pages/ManageCourse.vue';
import PageNotFound from '../pages/404.vue'
import AttendanceTrack from '../pages/course/AttendanceTrack.vue'
import AttendanceEventCard from '../pages/course/components/AttendanceEventCard.vue';
import LocationCard from '../pages/course/components/LocationCard.vue';
import ManagePeopleCard from '../pages/course/components/ManagePeopleCard.vue';

const routes = [
  {
    path: "/",
    component: AllCourses,
  },
  {
    path: '/login',
    name: 'Login',
    component: LoginPage
  },
  {
    path: '/course',
    name: 'Course',
    component: Course,
    children: [
      {
        path: '',
        name: 'Courses',
        component: AllCourses,
      },
      {
        path: ':id',
        name: 'SingleCourse',
        component: SingleCourse,
        children: [
          {
            path: 'attendance',
            name: 'AttendanceEventCard',
            component: AttendanceEventCard
          },
          {
            path: 'location',
            name: 'LocationCard',
            component: LocationCard
          },
          {
            path: 'people',
            name: 'ManagePeopleCard',
            component: ManagePeopleCard
          }
        ]
      },
      // {
      //   path: ':id/attendance',
      //   name: 'AttendanceTrack',
      //   component: AttendanceTrack
      // },
    ]
  },
  {
    path: '/manage-account',
    name: 'ManageAccount',
    component: ManageAccount
  },
  {
    path: '/manage-course',
    name: 'ManageCourse',
    component: ManageCourse
  },
  {
    path: "/:notFound",
    component: PageNotFound,
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router

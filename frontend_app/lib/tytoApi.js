import axios from 'axios'
import { ElMessage } from 'element-plus'
import cookieManager from './cookieManager'

const api = axios.create({
  baseURL: '/api'
})

// Request interceptor: attach auth
api.interceptors.request.use(config => {
  const account = cookieManager.getAccount()
  if (account?.credential) {
    config.headers.Authorization = `Bearer ${account.credential}`
  }
  return config
})

// Response interceptor: handle errors with toast notifications
api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      cookieManager.onLogout()
      window.location.href = '/login'
    } else if (error.response?.status === 422) {
      ElMessage.warning(error.response.data?.message || 'Validation error')
    } else if (error.response?.status >= 500) {
      ElMessage.error('Server error — please try again later')
    }
    // Still reject so callers can add contextual handling if needed
    return Promise.reject(error)
  }
)

export default api

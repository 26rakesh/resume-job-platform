import axios from 'axios'

// In production, API URL is relative (same origin)
// In development, use localhost:8000
const API_BASE_URL = import.meta.env.MODE === 'production'
  ? '/api'
  : (import.meta.env.VITE_API_URL || 'http://localhost:8000/api')

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
  },
  withCredentials: true, // Required for cookie-based authentication with CSRF
})

// Initialize CSRF token on app load
export const initCsrf = async () => {
  try {
    await axios.get('/sanctum/csrf-cookie', {
      withCredentials: true,
      baseURL: import.meta.env.MODE === 'production' ? '' : 'http://localhost:8000',
    })
  } catch (error) {
    console.error('Failed to initialize CSRF token:', error)
  }
}

api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Do NOT redirect on 401 here — AuthContext handles unauthenticated
    // state and ProtectedRoute performs client-side navigation.
    // A global window.location redirect causes a reload loop on startup
    // when /api/user returns 401 for anonymous visitors.
    if (error.response?.status === 419) {
      // CSRF token mismatch - reinitialize
      initCsrf()
    }
    return Promise.reject(error)
  }
)

export default api

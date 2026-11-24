import { useState, useEffect, ReactNode } from 'react'
import api, { initCsrf } from '../lib/api'
import { AuthContext } from './auth-context-definition'
import type { User } from './auth-context-definition'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Initialize CSRF token and check session on mount
    initCsrf()
    fetchUser()
  }, [])

  const fetchUser = async () => {
    try {
      const response = await api.get('/user')
      setUser(response.data.user)
    } catch {
      setUser(null)
    } finally {
      setLoading(false)
    }
  }

  const login = async (email: string, password: string) => {
    const response = await api.post('/login', { email, password })
    setUser(response.data.user)
  }

  const register = async (name: string, email: string, password: string, passwordConfirmation: string) => {
    const response = await api.post('/register', {
      name,
      email,
      password,
      password_confirmation: passwordConfirmation,
    })
    setUser(response.data.user)
  }

  const logout = async () => {
    try {
      await api.post('/logout')
    } catch {
      // Continue with logout even if API call fails
    } finally {
      setUser(null)
    }
  }

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

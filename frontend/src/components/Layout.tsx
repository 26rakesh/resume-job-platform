import { ReactNode } from 'react'
import { useLocation } from 'react-router-dom'
import { Sidebar } from './Sidebar'

interface LayoutProps {
  children: ReactNode
  title?: string
}

const pageTitles: Record<string, string> = {
  '/': 'Dashboard',
  '/candidates': 'Candidates',
  '/resumes': 'Resume Management',
  '/jobs': 'Job Discovery',
  '/matches': 'Job Matches',
  '/applications': 'Applications',
  '/settings': 'Settings',
}

export function Layout({ children, title }: LayoutProps) {
  const location = useLocation()
  const pageTitle = title || pageTitles[location.pathname] || 'Dashboard'

  return (
    <div className="flex min-h-screen bg-slate-50">
      <Sidebar />
      <main className="flex-1 flex flex-col">
        <header className="bg-white border-b border-slate-200 px-8 py-4">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-semibold text-slate-800">{pageTitle}</h2>
            <div className="flex items-center gap-4">
              <span className="text-sm text-slate-500">Last sync: Just now</span>
            </div>
          </div>
        </header>
        <div className="flex-1 p-8">{children}</div>
      </main>
    </div>
  )
}

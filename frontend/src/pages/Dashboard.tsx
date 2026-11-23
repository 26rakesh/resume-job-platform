import { Layout } from '../components/Layout'
import {
  Users,
  FileText,
  Briefcase,
  TrendingUp,
  CheckCircle,
  AlertCircle,
} from 'lucide-react'

const summaryCards = [
  { label: 'Total Candidates', value: '0', icon: Users, color: 'bg-blue-500' },
  { label: 'Resumes Uploaded', value: '0', icon: FileText, color: 'bg-green-500' },
  { label: 'Active Jobs', value: '0', icon: Briefcase, color: 'bg-purple-500' },
  { label: 'Pending Matches', value: '0', icon: TrendingUp, color: 'bg-orange-500' },
]

const recentActivity = [
  { id: 1, action: 'New candidate added', time: '2 hours ago', type: 'candidate' },
  { id: 2, action: 'Resume uploaded for John Doe', time: '5 hours ago', type: 'resume' },
  { id: 3, action: 'Job match generated', time: '1 day ago', type: 'match' },
]

const candidates = [
  { id: 1, name: 'John Doe', email: 'john@example.com', status: 'Active', resumes: 2 },
  { id: 2, name: 'Jane Smith', email: 'jane@example.com', status: 'Active', resumes: 1 },
  { id: 3, name: 'Bob Johnson', email: 'bob@example.com', status: 'Pending', resumes: 0 },
]

export default function Dashboard() {
  return (
    <Layout>
      <div className="space-y-8">
        <div>
          <p className="text-slate-500">Overview of your recruitment intelligence</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {summaryCards.map((card) => {
            const Icon = card.icon
            return (
              <div key={card.label} className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-slate-500 text-sm font-medium">{card.label}</p>
                    <p className="text-3xl font-bold text-slate-800 mt-2">{card.value}</p>
                  </div>
                  <div className={`${card.color} w-12 h-12 rounded-lg flex items-center justify-center`}>
                    <Icon className="text-white" size={24} />
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
            <h2 className="text-lg font-semibold text-slate-800 mb-4">Recent Activity</h2>
            <div className="space-y-4">
              {recentActivity.map((activity) => {
                const Icon =
                  activity.type === 'candidate'
                    ? Users
                    : activity.type === 'resume'
                    ? FileText
                    : CheckCircle
                return (
                  <div key={activity.id} className="flex items-start gap-3">
                    <div className="w-8 h-8 bg-slate-100 rounded-full flex items-center justify-center flex-shrink-0">
                      <Icon size={16} className="text-slate-600" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-slate-700">{activity.action}</p>
                      <p className="text-xs text-slate-400 mt-1">{activity.time}</p>
                    </div>
                  </div>
                )
              })}
              {recentActivity.length === 0 && (
                <p className="text-slate-400 text-sm text-center py-4">No recent activity</p>
              )}
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
            <h2 className="text-lg font-semibold text-slate-800 mb-4">Candidate Overview</h2>
            <div className="space-y-3">
              {candidates.map((candidate) => (
                <div
                  key={candidate.id}
                  className="flex items-center justify-between p-3 bg-slate-50 rounded-lg"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-primary-600 rounded-full flex items-center justify-center text-white font-medium">
                      {candidate.name.charAt(0)}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-slate-800">{candidate.name}</p>
                      <p className="text-xs text-slate-500">{candidate.email}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-xs text-slate-500">{candidate.resumes} resumes</span>
                    <span
                      className={`px-2 py-1 rounded-full text-xs font-medium ${
                        candidate.status === 'Active'
                          ? 'bg-green-100 text-green-700'
                          : 'bg-yellow-100 text-yellow-700'
                      }`}
                    >
                      {candidate.status}
                    </span>
                  </div>
                </div>
              ))}
              {candidates.length === 0 && (
                <p className="text-slate-400 text-sm text-center py-4">No candidates yet</p>
              )}
            </div>
          </div>
        </div>

        <div className="bg-amber-50 border border-amber-200 rounded-xl p-6">
          <div className="flex items-start gap-3">
            <AlertCircle className="text-amber-600 flex-shrink-0" size={20} />
            <div>
              <h3 className="font-medium text-amber-800">Setup Required</h3>
              <p className="text-sm text-amber-700 mt-1">
                Add your first candidate and upload resumes to start using AI-powered job matching.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  )
}

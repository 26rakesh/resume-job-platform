import { Layout } from '../components/Layout'
import { Users, Plus, Search, Filter } from 'lucide-react'

export default function Candidates() {
  return (
    <Layout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <p className="text-slate-500">Manage your candidate pool</p>
          <button className="flex items-center gap-2 bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700 transition-colors">
            <Plus size={20} />
            Add Candidate
          </button>
        </div>

        <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
          <div className="flex items-center gap-4 mb-6">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
              <input
                type="text"
                placeholder="Search candidates..."
                className="w-full pl-10 pr-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
              />
            </div>
            <button className="flex items-center gap-2 px-4 py-2 border border-slate-300 rounded-lg hover:bg-slate-50 transition-colors">
              <Filter size={20} />
              Filters
            </button>
          </div>

          <div className="text-center py-12">
            <Users className="mx-auto text-slate-300" size={64} />
            <h3 className="text-lg font-medium text-slate-800 mt-4">No candidates yet</h3>
            <p className="text-slate-500 mt-2">Add your first candidate to get started</p>
            <button className="mt-4 bg-primary-600 text-white px-6 py-2 rounded-lg hover:bg-primary-700 transition-colors">
              Add Candidate
            </button>
          </div>
        </div>
      </div>
    </Layout>
  )
}

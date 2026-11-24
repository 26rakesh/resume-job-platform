import { Layout } from '../components/Layout'
import { Briefcase, Search, Plus, RefreshCw } from 'lucide-react'

export default function JobDiscovery() {
  return (
    <Layout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <p className="text-slate-500">Discover and manage job opportunities</p>
          <div className="flex items-center gap-3">
            <button className="flex items-center gap-2 px-4 py-2 border border-slate-300 rounded-lg hover:bg-slate-50 transition-colors">
              <RefreshCw size={20} />
              Refresh
            </button>
            <button className="flex items-center gap-2 bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700 transition-colors">
              <Plus size={20} />
              Add Job
            </button>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
          <div className="flex items-center gap-4 mb-6">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
              <input
                type="text"
                placeholder="Search jobs..."
                className="w-full pl-10 pr-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
              />
            </div>
          </div>

          <div className="text-center py-12">
            <Briefcase className="mx-auto text-slate-300" size={64} />
            <h3 className="text-lg font-medium text-slate-800 mt-4">No jobs discovered yet</h3>
            <p className="text-slate-500 mt-2">Add jobs manually or enable AI-powered job discovery</p>
            <button className="mt-4 bg-primary-600 text-white px-6 py-2 rounded-lg hover:bg-primary-700 transition-colors">
              Add Job
            </button>
          </div>
        </div>
      </div>
    </Layout>
  )
}

import { Layout } from '../components/Layout'
import { Settings as SettingsIcon, Key, Database, Bell, Shield } from 'lucide-react'

export default function Settings() {
  return (
    <Layout>
      <div className="space-y-6">
        <p className="text-slate-500">Configure platform settings and preferences</p>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
            <div className="flex items-center gap-3 mb-4">
              <Key className="text-primary-600" size={24} />
              <h2 className="text-lg font-semibold text-slate-800">API Configuration</h2>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">Gemini API Key</label>
                <input
                  type="password"
                  placeholder="Enter your Gemini API key"
                  className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                />
                <p className="text-xs text-slate-500 mt-1">Used for AI-powered resume parsing and job matching</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">OpenAI API Key (Optional)</label>
                <input
                  type="password"
                  placeholder="Enter your OpenAI API key"
                  className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                />
                <p className="text-xs text-slate-500 mt-1">Alternative AI provider (future support)</p>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
            <div className="flex items-center gap-3 mb-4">
              <Database className="text-primary-600" size={24} />
              <h2 className="text-lg font-semibold text-slate-800">Database Settings</h2>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">Database Host</label>
                <input
                  type="text"
                  placeholder="localhost"
                  className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-2">Database Name</label>
                <input
                  type="text"
                  placeholder="jobs_platform"
                  className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                />
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
            <div className="flex items-center gap-3 mb-4">
              <Bell className="text-primary-600" size={24} />
              <h2 className="text-lg font-semibold text-slate-800">Notifications</h2>
            </div>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-slate-700">Email notifications</p>
                  <p className="text-xs text-slate-500">Receive email for new matches</p>
                </div>
                <input type="checkbox" className="w-5 h-5 text-primary-600 rounded" />
              </div>
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-slate-700">Application updates</p>
                  <p className="text-xs text-slate-500">Notify when applications are submitted</p>
                </div>
                <input type="checkbox" className="w-5 h-5 text-primary-600 rounded" />
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
            <div className="flex items-center gap-3 mb-4">
              <Shield className="text-primary-600" size={24} />
              <h2 className="text-lg font-semibold text-slate-800">Security</h2>
            </div>
            <div className="space-y-4">
              <div>
                <p className="text-sm font-medium text-slate-700">Change Password</p>
                <input
                  type="password"
                  placeholder="New password"
                  className="w-full mt-2 px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                />
              </div>
              <div>
                <p className="text-sm font-medium text-slate-700">Session Timeout</p>
                <select className="w-full mt-2 px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none">
                  <option>30 minutes</option>
                  <option>1 hour</option>
                  <option>4 hours</option>
                  <option>24 hours</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        <div className="flex justify-end">
          <button className="bg-primary-600 text-white px-6 py-2 rounded-lg hover:bg-primary-700 transition-colors">
            Save Settings
          </button>
        </div>
      </div>
    </Layout>
  )
}

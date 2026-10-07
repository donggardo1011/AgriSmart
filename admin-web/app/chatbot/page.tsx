'use client';

import { useEffect, useState } from 'react';
import AdminLayout from '@/app/(admin)/layout';
import { apiRequest, authHeaders } from '@/lib/api';

interface Disease {
  id: number;
  key: string;
  display_name: string;
  severity: string;
  urgency: string;
  explanation: string;
  is_active: boolean;
  causal_agent?: string;
  symptoms_summary_en?: string;
  prevention_summary_en?: string;
  treatment_summary_en?: string;
}

export default function ChatbotAdminPage() {
  const [diseases, setDiseases] = useState<Disease[]>([]);
  const [editing, setEditing] = useState<Disease | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    void load();
  }, []);

  async function load() {
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const data = await apiRequest<Disease[]>('/api/diseases', {
        headers: authHeaders(token),
      });
      setDiseases(data);
    } catch (err) {
      console.error('Failed to load diseases', err);
    }
  }

  async function save() {
    if (!editing) return;
    setSaving(true);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      await apiRequest(`/api/diseases/${editing.id}`, {
        method: 'PUT',
        headers: authHeaders(token),
        body: JSON.stringify(editing),
      });
      setEditing(null);
      await load();
    } catch {
      alert('Failed to save changes');
    } finally {
      setSaving(false);
    }
  }

  return (
    <AdminLayout>
      <div className="mx-auto max-w-[1240px] space-y-8">
        <div>
          <h1 className="page-title">Disease Knowledge Base Manager</h1>
          <p className="text-slate-600 mt-2">Configure technical disease profiles, symptoms, prevention strategies, and treatment protocols for the agricultural advisory system.</p>
        </div>

        <div className="grid grid-cols-[1.15fr_0.85fr] gap-6">
          <div className="table-shell">
            <div className="border-b px-6 py-5">
              <div className="section-kicker">Knowledge Base</div>
              <h2 className="mt-2 section-title">Supported Diseases</h2>
            </div>
            <table className="w-full text-left">
              <thead className="table-head">
                <tr>
                  <th className="px-6 py-4">Identifier</th>
                  <th className="px-6 py-4">Disease</th>
                  <th className="px-6 py-4">Risk Level</th>
                  <th className="px-6 py-4 text-right">Manage</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {diseases.map((disease) => (
                  <tr key={disease.id} className="hover:bg-slate-50/80">
                    <td className="table-cell font-mono text-xs text-slate-600">{disease.key}</td>
                    <td className="table-cell">
                      <div className="font-semibold text-slate-900">{disease.display_name}</div>
                      <div className="mt-1 text-xs text-slate-500">
                        {disease.causal_agent || 'Agent TBD'} {disease.is_active ? '• Active' : '• Disabled'}
                      </div>
                    </td>
                    <td className="table-cell">
                      <span className={disease.severity === 'High' ? 'badge bg-red-50 text-red-700' : disease.severity === 'Moderate' ? 'badge bg-amber-50 text-amber-700' : 'badge bg-green-50 text-green-700'}>
                        {disease.severity}
                      </span>
                    </td>
                    <td className="table-cell text-right">
                      <button className="btn-success text-sm" onClick={() => setEditing(disease)}>
                        Manage
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="card">
            {editing ? (
              <div>
                <div className="section-kicker">Disease Information Manager</div>
                <h2 className="mt-2 section-title">Technical Disease Profile</h2>
                <div className="mt-6 space-y-6">
                  {/* Basic Information */}
                  <div className="border-b pb-6">
                    <h3 className="font-semibold text-slate-900 mb-4">Basic Information</h3>
                    <div className="space-y-4">
                      <div>
                        <label className="field-label">Display Name</label>
                        <input 
                          className="input" 
                          value={editing.display_name} 
                          onChange={(e) => setEditing({ ...editing, display_name: e.target.value })} 
                          placeholder="e.g., Bacterial Blight"
                        />
                      </div>
                      <div>
                        <label className="field-label">Causal Agent</label>
                        <input 
                          className="input" 
                          value={editing.causal_agent || ''} 
                          onChange={(e) => setEditing({ ...editing, causal_agent: e.target.value })} 
                          placeholder="e.g., Xanthomonas oryzae pv. oryzae"
                        />
                      </div>
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="field-label">Severity Level</label>
                          <select 
                            className="input" 
                            value={editing.severity} 
                            onChange={(e) => setEditing({ ...editing, severity: e.target.value })}
                          >
                            <option value="High">High</option>
                            <option value="Moderate">Moderate</option>
                            <option value="Low">Low</option>
                          </select>
                        </div>
                        <div>
                          <label className="field-label">Status</label>
                          <select 
                            className="input" 
                            value={editing.is_active ? 'active' : 'inactive'} 
                            onChange={(e) => setEditing({ ...editing, is_active: e.target.value === 'active' })}
                          >
                            <option value="active">Active</option>
                            <option value="inactive">Disabled</option>
                          </select>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Disease Characteristics */}
                  <div className="border-b pb-6">
                    <h3 className="font-semibold text-slate-900 mb-4">Disease Characteristics</h3>
                    <div className="space-y-4">
                      <div>
                        <label className="field-label">General Explanation</label>
                        <textarea 
                          rows={4} 
                          className="input resize-none" 
                          value={editing.explanation} 
                          onChange={(e) => setEditing({ ...editing, explanation: e.target.value })}
                          placeholder="Detailed scientific explanation of the disease..."
                        />
                      </div>
                      <div>
                        <label className="field-label">Symptoms Summary</label>
                        <textarea 
                          rows={3} 
                          className="input resize-none" 
                          value={editing.symptoms_summary_en || ''} 
                          onChange={(e) => setEditing({ ...editing, symptoms_summary_en: e.target.value })}
                          placeholder="Key symptoms to identify this disease..."
                        />
                      </div>
                    </div>
                  </div>

                  {/* Management & Control */}
                  <div className="border-b pb-6">
                    <h3 className="font-semibold text-slate-900 mb-4">Management & Control</h3>
                    <div className="space-y-4">
                      <div>
                        <label className="field-label">Prevention Methods</label>
                        <textarea 
                          rows={3} 
                          className="input resize-none" 
                          value={editing.prevention_summary_en || ''} 
                          onChange={(e) => setEditing({ ...editing, prevention_summary_en: e.target.value })}
                          placeholder="Cultural and preventive practices..."
                        />
                      </div>
                      <div>
                        <label className="field-label">Treatment/Control Measures</label>
                        <textarea 
                          rows={3} 
                          className="input resize-none" 
                          value={editing.treatment_summary_en || ''} 
                          onChange={(e) => setEditing({ ...editing, treatment_summary_en: e.target.value })}
                          placeholder="Recommended treatment options, chemicals, and protocols..."
                        />
                      </div>
                    </div>
                  </div>

                  {/* Response Urgency */}
                  <div>
                    <h3 className="font-semibold text-slate-900 mb-4">Response Protocol</h3>
                    <div>
                      <label className="field-label">Recommended Action</label>
                      <input 
                        className="input" 
                        value={editing.urgency} 
                        onChange={(e) => setEditing({ ...editing, urgency: e.target.value })}
                        placeholder="e.g., Act quickly to prevent spread and yield loss"
                      />
                    </div>
                  </div>
                </div>
                <div className="mt-8 flex gap-3 border-t pt-6">
                  <button className="btn-primary" onClick={save} disabled={saving}>{saving ? 'Saving...' : 'Save Changes'}</button>
                  <button className="btn-secondary" onClick={() => setEditing(null)}>Cancel</button>
                </div>
              </div>
            ) : (
              <div className="flex h-full flex-col justify-center rounded-2xl bg-gradient-to-br from-slate-50 to-slate-100 px-6 py-10 text-center">
                <div className="section-kicker">Disease Information Manager</div>
                <h2 className="mt-2 section-title">Select a Disease</h2>
                <p className="mt-3 text-sm leading-6 text-slate-600">
                  Choose a disease from the table to manage its technical profile, including causal agent, symptoms, prevention, and treatment information.
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}

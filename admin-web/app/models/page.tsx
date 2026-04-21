'use client';

import { useEffect, useState } from 'react';
import AdminLayout from '@/app/(admin)/layout';
import { apiRequest } from '@/lib/api';

interface ModelVersion {
  id: number;
  version: string;
  file_path: string;
  is_active: boolean;
  map_score?: number;
  precision?: number;
  recall?: number;
  f1_score?: number;
  classes?: string;
  description?: string;
  created_at: string;
}

const modelClasses = ['bacterial_blight', 'brown_spot', 'leaf_blast', 'sheath_blight', 'tungro'];

function formatClassLabel(value: string) {
  const labels: Record<string, string> = {
    bacterial_blight: 'Bacterial Blight',
    brown_spot: 'Brown Spot',
    leaf_blast: 'Leaf Blast',
    sheath_blight: 'Sheath Blight',
    smut: 'Sheath Blight',
    tungro: 'Tungro',
  };
  return labels[value] ?? value.replaceAll('_', ' ');
}

export default function ModelsPage() {
  const [activeModel, setActiveModel] = useState<ModelVersion | null>(null);
  const [versions, setVersions] = useState<ModelVersion[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newVersion, setNewVersion] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [newMap, setNewMap] = useState('');
  const [newPrecision, setNewPrecision] = useState('');
  const [newRecall, setNewRecall] = useState('');
  const [newFile, setNewFile] = useState<File | null>(null);

  async function fetchData() {
    try {
      setLoading(true);
      const [status, allVersions] = await Promise.all([
        apiRequest<ModelVersion>('/model/status'),
        apiRequest<ModelVersion[]>('/model/versions'),
      ]);
      setActiveModel(status);
      setVersions(allVersions);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void fetchData();
  }, []);

  const handleUpload = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newFile || !newVersion) return;

    try {
      setUploading(true);
      const formData = new FormData();
      formData.append('version', newVersion);
      formData.append('description', newDesc);
      formData.append('map_score', newMap);
      formData.append('precision', newPrecision);
      formData.append('recall', newRecall);
      formData.append('file', newFile);
      formData.append('classes', JSON.stringify(modelClasses));
      await apiRequest('/model/upload', { method: 'POST', body: formData });
      setNewVersion('');
      setNewDesc('');
      setNewMap('');
      setNewPrecision('');
      setNewRecall('');
      setNewFile(null);
      await fetchData();
    } catch (e: any) {
      alert(e.message);
    } finally {
      setUploading(false);
    }
  };

  const handleActivate = async (id: number) => {
    try {
      await apiRequest(`/model/activate/${id}`, { method: 'POST' });
      await fetchData();
    } catch (e: any) {
      alert(e.message);
    }
  };

  const classes = activeModel?.classes ? JSON.parse(activeModel.classes) : [];

  return (
    <AdminLayout>
      <div className="mx-auto max-w-[1240px] space-y-8">
        <div>
          <h1 className="page-title">Models</h1>
        </div>

        {error && <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

        <div className="grid grid-cols-[1.15fr_0.85fr] gap-6">
          <div className="space-y-6">
            <div className="card">
              <div className="section-kicker">Active model</div>
              <h2 className="mt-2 section-title">Live inference status</h2>
              <div className="mt-6 grid grid-cols-3 gap-4">
                <div className="rounded-2xl border bg-slate-50 p-4"><div className="stat-label">mAP</div><div className="mt-2 text-2xl font-semibold text-slate-900">{(activeModel?.map_score ?? 0).toFixed(2)}</div></div>
                <div className="rounded-2xl border bg-slate-50 p-4"><div className="stat-label">Precision</div><div className="mt-2 text-2xl font-semibold text-slate-900">{(activeModel?.precision ?? 0).toFixed(2)}</div></div>
                <div className="rounded-2xl border bg-slate-50 p-4"><div className="stat-label">Recall</div><div className="mt-2 text-2xl font-semibold text-slate-900">{(activeModel?.recall ?? 0).toFixed(2)}</div></div>
              </div>
              <div className="mt-6 flex flex-wrap gap-2">
                {classes.map((name: string) => (
                  <span key={name} className="badge badge-slate">{formatClassLabel(name)}</span>
                ))}
              </div>
            </div>

            <div className="table-shell">
              <div className="border-b px-6 py-5">
                <div className="section-kicker">Version history</div>
                <h2 className="mt-2 section-title">Saved models</h2>
              </div>
              <table className="w-full text-left">
                <thead className="table-head">
                  <tr>
                    <th className="px-6 py-4">Version</th>
                    <th className="px-6 py-4">mAP</th>
                    <th className="px-6 py-4">Created</th>
                    <th className="px-6 py-4 text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {versions.map((version) => (
                    <tr key={version.id} className="hover:bg-slate-50/80">
                      <td className="table-cell">
                        <div className="font-medium text-slate-900">{version.version}</div>
                        <div className="mt-1 text-xs text-slate-500">{version.description || 'No description'}</div>
                      </td>
                      <td className="table-cell text-slate-600">{(version.map_score ?? 0).toFixed(2)}</td>
                      <td className="table-cell text-slate-500">{new Date(version.created_at).toLocaleDateString()}</td>
                      <td className="table-cell text-right">
                        {version.is_active ? (
                          <span className="badge badge-green">Active</span>
                        ) : (
                          <button className="btn-success" onClick={() => handleActivate(version.id)}>Activate</button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="card">
            <div className="section-kicker">Upload</div>
            <h2 className="mt-2 section-title">Add a new model version</h2>
            <form onSubmit={handleUpload} className="mt-6 space-y-4">
              <div>
                <label className="field-label">Version</label>
                <input className="input" value={newVersion} onChange={(e) => setNewVersion(e.target.value)} required />
              </div>
              <div>
                <label className="field-label">Description</label>
                <input className="input" value={newDesc} onChange={(e) => setNewDesc(e.target.value)} />
              </div>
              <div>
                <label className="field-label">mAP score</label>
                <input className="input" type="number" step="0.01" value={newMap} onChange={(e) => setNewMap(e.target.value)} />
              </div>
              <div>
                <label className="field-label">Precision</label>
                <input className="input" type="number" step="0.01" value={newPrecision} onChange={(e) => setNewPrecision(e.target.value)} />
              </div>
              <div>
                <label className="field-label">Recall</label>
                <input className="input" type="number" step="0.01" value={newRecall} onChange={(e) => setNewRecall(e.target.value)} />
              </div>
              <div>
                <label className="field-label">Weights file</label>
                <input className="input" type="file" accept=".pt" onChange={(e) => setNewFile(e.target.files?.[0] || null)} required />
              </div>
              <button type="submit" className="btn-primary w-full justify-center" disabled={uploading}>
                {uploading ? 'Uploading...' : 'Upload model'}
              </button>
            </form>
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}

'use client';

import { useEffect, useMemo, useState } from 'react';
import AdminLayout from '@/app/(admin)/layout';
import { apiRequest, authHeaders, getApiBaseUrl } from '@/lib/api';

interface DatasetItem {
  id: number;
  label: string;
  split: string;
  image_url: string;
  created_at: string;
}

interface StatsResponse {
  total: number;
  by_label: Record<string, number>;
  by_split: Record<string, number>;
}

const allowedLabels = ['bacterial_blight', 'brown_spot', 'leaf_blast', 'sheath_blight', 'tungro'];
const allowedSplits = ['train', 'val', 'test'] as const;

function formatLabel(value: string) {
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

export default function DatasetsPage() {
  const [items, setItems] = useState<DatasetItem[]>([]);
  const [stats, setStats] = useState<StatsResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [filtersLabel, setFiltersLabel] = useState('all');
  const [filtersSplit, setFiltersSplit] = useState('all');
  const [showUpload, setShowUpload] = useState(false);
  const [uploadLabel, setUploadLabel] = useState('brown_spot');
  const [uploadSplit, setUploadSplit] = useState<(typeof allowedSplits)[number]>('train');
  const [uploadFiles, setUploadFiles] = useState<FileList | null>(null);
  const [uploading, setUploading] = useState(false);

  useEffect(() => {
    void load();
  }, []);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const [list, st] = await Promise.all([
        apiRequest<DatasetItem[]>('/admin/datasets', { headers: authHeaders(token) }),
        apiRequest<StatsResponse>('/admin/datasets/stats', { headers: authHeaders(token) }),
      ]);
      setItems(list.filter((item) => allowedLabels.includes(item.label)));
      setStats({
        total: list.filter((item) => allowedLabels.includes(item.label)).length,
        by_label: Object.fromEntries(Object.entries(st.by_label).filter(([k]) => allowedLabels.includes(k))),
        by_split: st.by_split,
      });
    } catch (err: any) {
      setError(err.message ?? 'Failed to load datasets');
    } finally {
      setLoading(false);
    }
  }

  async function uploadSelected() {
    if (!uploadFiles?.length) return;
    setUploading(true);
    setError(null);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const base = getApiBaseUrl();
      for (let i = 0; i < uploadFiles.length; i += 1) {
        const file = uploadFiles.item(i);
        if (!file) continue;
        const form = new FormData();
        form.append('image', file);
        const res = await fetch(`${base}/admin/datasets/upload?label=${encodeURIComponent(uploadLabel)}&split=${encodeURIComponent(uploadSplit)}`, {
          method: 'POST',
          headers: authHeaders(token),
          body: form,
        });
        if (!res.ok) throw new Error(`Upload failed (${res.status})`);
      }
      setShowUpload(false);
      setUploadFiles(null);
      await load();
    } catch (err: any) {
      setError(err.message ?? 'Upload failed');
    } finally {
      setUploading(false);
    }
  }

  const filteredItems = useMemo(() => {
    return items.filter((item) => {
      if (filtersLabel !== 'all' && item.label !== filtersLabel) return false;
      if (filtersSplit !== 'all' && item.split !== filtersSplit) return false;
      if (search.trim() && !item.label.toLowerCase().includes(search.trim().toLowerCase())) return false;
      return true;
    });
  }, [filtersLabel, filtersSplit, items, search]);

  return (
    <AdminLayout>
      <div className="mx-auto max-w-[1320px] space-y-8">
        <div className="flex items-end justify-between gap-4">
          <div>
            <h1 className="page-title">Datasets</h1>
          </div>
          <div className="flex gap-3">
            <button className="btn-secondary" onClick={() => void load()}>Refresh</button>
            <button className="btn-primary" onClick={() => setShowUpload(true)}>Upload images</button>
          </div>
        </div>

        {error && <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

        <div className="grid grid-cols-3 gap-6">
          <div className="card"><div className="stat-label">Total items</div><div className="mt-3 stat-value">{stats?.total ?? 0}</div></div>
          <div className="card"><div className="stat-label">Train split</div><div className="mt-3 stat-value">{stats?.by_split.train ?? 0}</div></div>
          <div className="card"><div className="stat-label">Validation + test</div><div className="mt-3 stat-value">{(stats?.by_split.val ?? 0) + (stats?.by_split.test ?? 0)}</div></div>
        </div>

        <div className="panel">
          <div className="grid grid-cols-[1fr_180px_180px] gap-4 border-b px-6 py-5">
            <input className="input" placeholder="Search by label" value={search} onChange={(e) => setSearch(e.target.value)} />
            <select className="input" value={filtersLabel} onChange={(e) => setFiltersLabel(e.target.value)}>
              <option value="all">All labels</option>
              {allowedLabels.map((label) => <option key={label} value={label}>{formatLabel(label)}</option>)}
            </select>
            <select className="input" value={filtersSplit} onChange={(e) => setFiltersSplit(e.target.value)}>
              <option value="all">All splits</option>
              {allowedSplits.map((split) => <option key={split} value={split}>{split}</option>)}
            </select>
          </div>

          {filteredItems.length === 0 && !loading ? (
            <div className="empty-state m-6">No dataset items match the current filters.</div>
          ) : (
            <table className="w-full text-left">
              <thead className="table-head">
                <tr>
                  <th className="px-6 py-4">Preview</th>
                  <th className="px-6 py-4">Label</th>
                  <th className="px-6 py-4">Split</th>
                  <th className="px-6 py-4">Created</th>
                  <th className="px-6 py-4 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredItems.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-50/80">
                    <td className="table-cell">
                      <img src={item.image_url} alt="dataset" className="h-14 w-14 rounded-xl object-cover" />
                    </td>
                    <td className="table-cell font-medium text-slate-900">{formatLabel(item.label)}</td>
                    <td className="table-cell"><span className="badge badge-slate">{item.split}</span></td>
                    <td className="table-cell text-slate-500">{new Date(item.created_at).toLocaleDateString()}</td>
                    <td className="table-cell text-right">
                      <a href={`/datasets/${item.id}/annotate`} className="btn-success">Annotate</a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {showUpload && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-6 backdrop-blur-sm">
            <div className="card w-full max-w-xl">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="section-kicker">Upload</div>
                  <h2 className="mt-2 section-title">Add dataset images</h2>
                </div>
                <button className="btn-success" onClick={() => setShowUpload(false)}>Close</button>
              </div>
              <div className="mt-6 grid grid-cols-2 gap-4">
                <div>
                  <label className="field-label">Label</label>
                  <select className="input" value={uploadLabel} onChange={(e) => setUploadLabel(e.target.value)}>
                    {allowedLabels.map((label) => <option key={label} value={label}>{formatLabel(label)}</option>)}
                  </select>
                </div>
                <div>
                  <label className="field-label">Split</label>
                  <select className="input" value={uploadSplit} onChange={(e) => setUploadSplit(e.target.value as (typeof allowedSplits)[number])}>
                    {allowedSplits.map((split) => <option key={split} value={split}>{split}</option>)}
                  </select>
                </div>
              </div>
              <div className="mt-4">
                <label className="field-label">Images</label>
                <input className="input" type="file" multiple onChange={(e) => setUploadFiles(e.target.files)} />
              </div>
              <div className="mt-6 flex justify-end gap-3">
                <button className="btn-success" onClick={() => setShowUpload(false)}>Cancel</button>
                <button className="btn-primary" onClick={() => void uploadSelected()} disabled={uploading || !uploadFiles?.length}>
                  {uploading ? 'Uploading...' : 'Upload'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </AdminLayout>
  );
}

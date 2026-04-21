'use client';

import { useState } from 'react';
import AdminLayout from '@/app/(admin)/layout';
import { getApiBaseUrl } from '@/lib/api';

export default function BackupPage() {
  const [downloading, setDownloading] = useState(false);

  const handleDownloadDb = async () => {
    try {
      setDownloading(true);
      const token = window.localStorage.getItem('admin_access_token');
      if (!token) {
        alert('Authentication token missing. Please log in again.');
        return;
      }

      const response = await fetch(`${getApiBaseUrl()}/admin/backup/db`, {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (!response.ok) throw new Error('Failed to download backup');

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `rldd_backup_${new Date().toISOString().split('T')[0]}.db`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error('Backup error:', error);
      alert('Failed to generate database backup.');
    } finally {
      setDownloading(false);
    }
  };

  return (
    <AdminLayout>
      <div className="mx-auto max-w-[1180px] space-y-8">
        <div>
          <h1 className="page-title">Backup</h1>
        </div>

        <div className="grid grid-cols-[1.2fr_0.8fr] gap-6">
          <div className="space-y-6">
            <div className="card">
              <div className="flex items-start justify-between gap-6">
                <div>
                  <div className="section-kicker">Database</div>
                  <h2 className="mt-2 section-title">SQLite snapshot</h2>
                  <p className="mt-3 text-sm leading-6 text-slate-500">
                    Export the latest copy of the database including users, predictions, activity logs, and dataset metadata.
                  </p>
                </div>
                <button className="btn-success" onClick={handleDownloadDb} disabled={downloading}>
                  {downloading ? 'Preparing...' : 'Download backup'}
                </button>
              </div>

              <div className="mt-6 grid grid-cols-2 gap-4 rounded-2xl border bg-slate-50 p-4 text-sm text-slate-600">
                <div>
                  <div className="stat-label">Storage path</div>
                  <div className="mt-2 font-mono text-slate-800">backend/users.db</div>
                </div>
                <div>
                  <div className="stat-label">Source</div>
                  <div className="mt-2 text-slate-800">Live environment</div>
                </div>
              </div>
            </div>

            <div className="card">
              <div className="section-kicker">Media assets</div>
              <h2 className="mt-2 section-title">Directories to include</h2>
              <div className="mt-6 grid grid-cols-2 gap-4">
                <div className="rounded-2xl border bg-slate-50 p-4">
                  <div className="text-sm font-medium text-slate-900">User scans</div>
                  <p className="mt-2 text-sm leading-6 text-slate-500">Uploaded leaf scans used for prediction history.</p>
                  <div className="mt-3 rounded-lg bg-white px-3 py-2 font-mono text-xs text-slate-700">/backend/uploads/</div>
                </div>
                <div className="rounded-2xl border bg-slate-50 p-4">
                  <div className="text-sm font-medium text-slate-900">Training dataset</div>
                  <p className="mt-2 text-sm leading-6 text-slate-500">Verified images prepared for annotation and retraining.</p>
                  <div className="mt-3 rounded-lg bg-white px-3 py-2 font-mono text-xs text-slate-700">/backend/dataset_clean/</div>
                </div>
              </div>
            </div>
          </div>

          <div className="card bg-emerald-600 text-white shadow-emerald-300/40">
            <div className="section-kicker text-emerald-100">Procedure</div>
            <h2 className="mt-2 text-xl font-semibold">Recommended routine</h2>
            <div className="mt-6 space-y-5 text-sm leading-6 text-emerald-50">
              <div>
                <div className="font-medium text-white">1. Pause writes</div>
                <p className="mt-1">Stop or quiet the backend before copying database files.</p>
              </div>
              <div>
                <div className="font-medium text-white">2. Export and copy</div>
                <p className="mt-1">Download the database snapshot and copy media directories to secure storage.</p>
              </div>
              <div>
                <div className="font-medium text-white">3. Verify and restore service</div>
                <p className="mt-1">Check backup integrity, then restart the service if it was paused.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}

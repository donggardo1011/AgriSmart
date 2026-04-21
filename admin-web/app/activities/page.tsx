'use client';

import { useEffect, useState, useRef } from 'react';
import { apiRequest, authHeaders } from '@/lib/api';
import AdminLayout from '@/app/(admin)/layout';

interface ActivityRow {
  id: number;
  user_id: number | null;
  username?: string | null;
  email?: string | null;
  location?: string | null;
  action: string;
  detail: string | null;
  created_at: string;
}

export default function ActivitiesPage() {
  const [rows, setRows] = useState<ActivityRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const tableRef = useRef<HTMLTableElement>(null);

  useEffect(() => {
    void load();
  }, []);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const list = await apiRequest<ActivityRow[]>('/admin/activities?limit=100', {
        headers: authHeaders(token),
      });
      setRows(list);
    } catch (err: any) {
      setError(err.message ?? 'Failed to load activities');
    } finally {
      setLoading(false);
    }
  }

  function prettyDetail(detail: string | null) {
    if (!detail) return '';
    try {
      return JSON.stringify(JSON.parse(detail), null, 2);
    } catch {
      return detail;
    }
  }

  function formatPHTime(dateString: string) {
    try {
      const date = new Date(dateString);
      // Format directly in Philippine Time (Asia/Manila is UTC+8)
      return date.toLocaleString('en-US', {
        timeZone: 'Asia/Manila',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: true,
      });
    } catch {
      return dateString;
    }
  }

  const downloadPDF = async () => {
    if (!tableRef.current) return;
    
    try {
      const { default: jsPDF } = await import('jspdf');
      const html2canvas = (await import('html2canvas')).default;
      
      const canvas = await html2canvas(tableRef.current);
      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF({
        orientation: 'landscape',
        unit: 'mm',
        format: 'a4',
      });
      
      const imgWidth = 280;
      const imgHeight = (canvas.height * imgWidth) / canvas.width;
      let heightLeft = imgHeight;
      let position = 0;

      pdf.addImage(imgData, 'PNG', 10, position, imgWidth, imgHeight);
      heightLeft -= 210;

      while (heightLeft > 0) {
        position = heightLeft - imgHeight;
        pdf.addPage();
        pdf.addImage(imgData, 'PNG', 10, position, imgWidth, imgHeight);
        heightLeft -= 210;
      }

      pdf.save(`activity-logs-${new Date().toISOString().split('T')[0]}.pdf`);
    } catch (err) {
      console.error('PDF export failed:', err);
      alert('Failed to generate PDF');
    }
  };

  return (
    <AdminLayout>
      <div className="mx-auto max-w-[1320px] space-y-8">
        <div className="flex items-end justify-between gap-4">
          <div>
            <h1 className="page-title">Activities</h1>
          </div>
          <div className="flex gap-3">
            <button className="btn-secondary" onClick={() => void load()}>
              Refresh
            </button>
            <button
              onClick={downloadPDF}
              disabled={rows.length === 0}
              className="px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition text-sm font-medium"
            >
              Export PDF
            </button>
          </div>
        </div>

        {error && <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

        <div className="table-shell">
          <div className="border-b px-6 py-5">
            <div className="section-kicker">Audit log</div>
            <h2 className="mt-2 section-title">Latest 100 events</h2>
          </div>

          {rows.length === 0 && !loading ? (
            <div className="empty-state m-6">No activity recorded yet.</div>
          ) : (
            <table ref={tableRef} className="w-full text-left">
              <thead className="table-head">
                <tr>
                  <th className="px-6 py-4">Action</th>
                  <th className="px-6 py-4">User</th>
                  <th className="px-6 py-4">Email</th>
                  <th className="px-6 py-4">Location</th>
                  <th className="px-6 py-4">Time</th>
                  <th className="px-6 py-4">Detail</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {rows.map((row) => (
                  <tr key={row.id} className="align-top hover:bg-slate-50/80">
                    <td className="table-cell">
                      <div className="font-medium text-slate-900">{row.action}</div>
                      <div className="mt-1 text-xs text-slate-400">#{row.id}</div>
                    </td>
                    <td className="table-cell text-sm text-slate-600">
                      {row.username ?? (row.user_id ? `User ${row.user_id}` : 'System')}
                    </td>
                    <td className="table-cell text-sm text-slate-600">
                      {row.email ?? '-'}
                    </td>
                    <td className="table-cell text-sm text-slate-600">
                      {row.location ?? '-'}
                    </td>
                    <td className="table-cell text-sm text-slate-500">{formatPHTime(row.created_at)}</td>
                    <td className="table-cell">
                      {row.detail ? (
                        <pre className="max-h-40 overflow-auto rounded-xl bg-slate-50 p-3 text-xs leading-5 text-slate-600">
                          {prettyDetail(row.detail)}
                        </pre>
                      ) : (
                        <span className="text-sm text-slate-400">No detail</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </AdminLayout>
  );
}

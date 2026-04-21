'use client';

import { useEffect, useState } from 'react';
import { apiRequest, authHeaders } from '@/lib/api';
import AdminLayout from '@/app/(admin)/layout';

interface UserRow {
  id: number;
  username: string;
  email: string;
  location?: string;
  role: string;
  is_active: boolean;
  status: string;  // "online" or "offline"
  created_at: string;
}

interface CountResponse {
  total: number;
  active: number;
  admins: number;
}

export default function UsersPage() {
  const [rows, setRows] = useState<UserRow[]>([]);
  const [counts, setCounts] = useState<CountResponse | null>(null);
  const [q, setQ] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedUserId, setSelectedUserId] = useState<number | null>(null);
  const [changingRole, setChangingRole] = useState(false);

  useEffect(() => {
    void load();
  }, []);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const [cnt, list] = await Promise.all([
        apiRequest<CountResponse>('/admin/users/count', { headers: authHeaders(token) }),
        apiRequest<UserRow[]>(`/admin/users${q ? `?q=${encodeURIComponent(q)}` : ''}`, { headers: authHeaders(token) }),
      ]);
      setCounts(cnt);
      setRows(list);
    } catch (err: any) {
      setError(err.message ?? 'Failed to load users');
    } finally {
      setLoading(false);
    }
  }

  async function changeUserRole(userId: number, newRole: string) {
    const token = window.localStorage.getItem('admin_access_token') ?? '';
    setChangingRole(true);
    try {
      await apiRequest(`/admin/users/${userId}/role`, {
        method: 'POST',
        headers: authHeaders(token),
        body: JSON.stringify({ role: newRole }),
      });
      
      // Update local state
      setRows(rows.map(u => u.id === userId ? { ...u, role: newRole } : u));
      setSelectedUserId(null);
      
      // Reload to get updated counts
      void load();
    } catch (err: any) {
      setError(err.message ?? 'Failed to change role');
    } finally {
      setChangingRole(false);
    }
  }

  return (
    <AdminLayout>
      <div className="mx-auto max-w-[1240px] space-y-8">
        <div className="flex items-end justify-between gap-4">
          <div>
            <h1 className="page-title">Users</h1>
          </div>
          <button className="btn-secondary" onClick={() => void load()}>
            Refresh
          </button>
        </div>

        {error && <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

        <div className="grid grid-cols-3 gap-6">
          <div className="card"><div className="stat-label">Total users</div><div className="mt-3 stat-value">{counts?.total ?? 0}</div></div>
          <div className="card"><div className="stat-label">Active users</div><div className="mt-3 stat-value">{counts?.active ?? 0}</div></div>
          <div className="card"><div className="stat-label">Admins</div><div className="mt-3 stat-value">{counts?.admins ?? 0}</div></div>
        </div>

        <div className="panel">
          <div className="flex items-center justify-between border-b px-6 py-5">
            <div>
              <div className="section-kicker">Directory</div>
              <h2 className="mt-2 section-title">Registered accounts</h2>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault();
                void load();
              }}
              className="w-72"
            >
              <input className="input" placeholder="Search username or email" value={q} onChange={(e) => setQ(e.target.value)} />
            </form>
          </div>

          {rows.length === 0 && !loading ? (
            <div className="empty-state m-6">No users found.</div>
          ) : (
            <table className="w-full text-left">
              <thead className="table-head">
                <tr>
                  <th className="px-6 py-4">User</th>
                  <th className="px-6 py-4">Location</th>
                  <th className="px-6 py-4">Role</th>
                  <th className="px-6 py-4">Status</th>
                  <th className="px-6 py-4">Action</th>
                  <th className="px-6 py-4 text-right">Created</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {rows.map((user) => (
                  <tr key={user.id} className="hover:bg-slate-50/80">
                    <td className="table-cell">
                      <div className="flex items-center gap-3">
                        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-100 text-sm font-medium text-slate-700">
                          {user.username[0].toUpperCase()}
                        </div>
                        <div>
                          <div className="font-medium text-slate-900">{user.username}</div>
                          <div className="text-xs text-slate-500">{user.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="table-cell text-sm text-slate-600">
                      {user.location || '-'}
                    </td>
                    <td className="table-cell">
                      <span className={user.role === 'admin' ? 'badge badge-green' : 'badge badge-slate'}>{user.role}</span>
                    </td>
                    <td className="table-cell text-sm">
                      <div className="flex items-center gap-2">
                        <span className={`inline-block h-2 w-2 rounded-full ${user.status === 'online' ? 'bg-emerald-500' : 'bg-slate-300'}`} />
                        <span className={user.status === 'online' ? 'text-emerald-700 font-medium' : 'text-slate-500'}>
                          {user.status === 'online' ? 'Online' : 'Offline'}
                        </span>
                      </div>
                    </td>
                    <td className="table-cell">
                      {selectedUserId === user.id ? (
                        <div className="flex gap-2">
                          <button
                            onClick={() => void changeUserRole(user.id, user.role === 'admin' ? 'user' : 'admin')}
                            disabled={changingRole}
                            className="px-3 py-1 text-sm rounded-lg bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50"
                          >
                            {changingRole ? 'Changing...' : 'Confirm'}
                          </button>
                          <button
                            onClick={() => setSelectedUserId(null)}
                            disabled={changingRole}
                            className="px-3 py-1 text-sm rounded-lg bg-slate-200 text-slate-700 hover:bg-slate-300 disabled:opacity-50"
                          >
                            Cancel
                          </button>
                        </div>
                      ) : (
                        <select
                          value={user.role}
                          onChange={(e) => {
                            if (e.target.value !== user.role) {
                              setSelectedUserId(user.id);
                            }
                          }}
                          className="px-3 py-1 text-sm rounded-lg border border-slate-300 hover:border-slate-400 cursor-pointer"
                        >
                          <option value="user">User</option>
                          <option value="admin">Admin</option>
                        </select>
                      )}
                    </td>
                    <td className="table-cell text-right text-sm text-slate-500">{new Date(user.created_at).toLocaleDateString()}</td>
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

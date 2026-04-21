'use client';

import { useEffect, useState, useRef } from 'react';
import { BarChart, Bar, LineChart, Line, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import AdminLayout from '@/app/(admin)/layout';
import { apiRequest, authHeaders } from '@/lib/api';

interface UserCounts {
  total: number;
  active: number;
  admins: number;
}

interface DatasetStats {
  total: number;
  by_label: Record<string, number>;
  by_split: Record<string, number>;
}

interface DiseaseRanking {
  disease_key: string;
  disease_name: string;
  scan_count: number;
  rank: number;
  location?: string;
}

interface LatestDisease {
  disease: string;
  confidence: number;
  timestamp: string;
  username: string;
  location?: string;
}

interface AnalyticsDashboard {
  total_users: number;
  active_users: number;
  total_admins: number;
  total_scans: number;
  latest_diseases: LatestDisease[];
  popular_diseases: DiseaseRanking[];
  locations_count: Record<string, number>;
}

const palette = ['#0f766e', '#14b8a6', '#84cc16', '#f59e0b', '#6366f1'];
const diseaseColors: Record<string, string> = {
  bacterial_blight: '#ef4444',
  brown_spot: '#f97316',
  leaf_blast: '#eab308',
  sheath_blight: '#22c55e',
  tungro: '#3b82f6',
};

type TimeInterval = 'daily' | 'weekly' | 'monthly';

function formatLabel(value: string): string {
  const labels: Record<string, string> = {
    bacterial_blight: 'Bacterial Blight',
    brown_spot: 'Brown Spot',
    leaf_blast: 'Leaf Blast',
    sheath_blight: 'Sheath Blight',
    tungro: 'Tungro',
  };
  return labels[value] ?? value.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
}

function formatPHTime(dateString: string): string {
  try {
    let utcString = dateString;
    if (!utcString.includes('Z') && !utcString.includes('+') && !utcString.includes('-', utcString.indexOf('T'))) {
      utcString = dateString + 'Z';
    }
    
    const date = new Date(utcString);
    return date.toLocaleString('en-US', {
      timeZone: 'Asia/Manila',
      month: '2-digit',
      day: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: true,
    });
  } catch {
    return dateString;
  }
}


export default function DashboardPage() {
  const [userCounts, setUserCounts] = useState<UserCounts | null>(null);
  const [datasetStats, setDatasetStats] = useState<DatasetStats | null>(null);
  const [analytics, setAnalytics] = useState<AnalyticsDashboard | null>(null);
  
  // State for filters and pagination
  const [diseaseInterval, setDiseaseInterval] = useState<TimeInterval>('monthly');
  const [selectedLocation, setSelectedLocation] = useState<string | null>(null);
  const [scansPage, setScansPage] = useState(1);
  const [scansPerPage] = useState(5);
  
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const diseaseTableRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    void load();
  }, []);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const [uc, ds, an] = await Promise.all([
        apiRequest<UserCounts>('/admin/users/count', { headers: authHeaders(token) }),
        apiRequest<DatasetStats>('/admin/datasets/stats', { headers: authHeaders(token) }),
        apiRequest<AnalyticsDashboard>('/analytics/dashboard', { headers: authHeaders(token) }),
      ]);
      setUserCounts(uc);
      setDatasetStats(ds);
      setAnalytics(an);
    } catch (err: any) {
      setError(err.message ?? 'Failed to load dashboard');
    } finally {
      setLoading(false);
    }
  }

  // Get available locations from analytics
  const availableLocations = analytics ? Object.keys(analytics.locations_count) : [];

  // Filter diseases by interval (simplified - actual backend would filter by date range)
  const filteredDiseases = analytics?.popular_diseases || [];
  
  // Filter by location if selected
  const diseasesByLocation = selectedLocation && analytics
    ? filteredDiseases.filter(d => d.location === selectedLocation)
    : filteredDiseases;

  // Pagination for scans
  const filteredScans = analytics?.latest_diseases || [];
  const totalScans = filteredScans.length;
  const totalPages = Math.ceil(totalScans / scansPerPage);
  const paginatedScans = filteredScans.slice(
    (scansPage - 1) * scansPerPage,
    scansPage * scansPerPage
  );

  // Prepare chart data
  const locationData = analytics ? Object.entries(analytics.locations_count).map(([location, count]) => ({
    name: location,
    users: count,
  })) : [];

  const diseaseChartData = diseasesByLocation.map((d) => ({
    name: formatLabel(d.disease_key),
    scans: d.scan_count,
  }));

  const downloadPDF = async () => {
    if (!diseaseTableRef.current) return;
    
    try {
      const { default: jsPDF } = await import('jspdf');
      const html2canvas = (await import('html2canvas')).default;
      
      const canvas = await html2canvas(diseaseTableRef.current);
      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF();
      const imgWidth = 190;
      const imgHeight = (canvas.height * imgWidth) / canvas.width;
      pdf.addImage(imgData, 'PNG', 10, 10, imgWidth, imgHeight);
      pdf.save(`disease-report-${diseaseInterval}-${new Date().toISOString().split('T')[0]}.pdf`);
    } catch (err) {
      console.error('PDF export failed:', err);
      alert('Failed to generate PDF');
    }
  };

  if (loading) {
    return (
      <AdminLayout>
        <div className="flex h-40 items-center justify-center">
          <div className="text-lg text-slate-600">Loading dashboard...</div>
        </div>
      </AdminLayout>
    );
  }

  if (error) {
    return (
      <AdminLayout>
        <div className="rounded-lg bg-red-50 p-4 text-red-700">
          <p>Error: {error}</p>
          <button
            onClick={() => void load()}
            className="mt-4 rounded-lg bg-red-600 px-4 py-2 text-white hover:bg-red-700"
          >
            Retry
          </button>
        </div>
      </AdminLayout>
    );
  }

  return (
    <AdminLayout>
      <div className="space-y-8 p-8 max-w-[1600px]">
        {/* Page Header */}
        <div className="flex items-end justify-between">
          <div>
            <h1 className="text-4xl font-bold text-slate-900">Dashboard</h1>
            <p className="mt-2 text-slate-600">System overview and key metrics</p>
          </div>
          <button className="btn-secondary" onClick={() => void load()}>
            Refresh
          </button>
        </div>

        {/* Key Metrics */}
        <div className="grid gap-6 md:grid-cols-4">
          <div className="card">
            <h3 className="text-sm font-medium text-slate-500 uppercase tracking-wide">Total Users</h3>
            <p className="mt-3 text-4xl font-bold text-slate-900">{userCounts?.total ?? 0}</p>
            <div className="mt-4 grid grid-cols-2 gap-2 text-sm text-slate-600">
              <div><span className="text-slate-400">Active:</span> {userCounts?.active ?? 0}</div>
              <div><span className="text-slate-400">Admins:</span> {userCounts?.admins ?? 0}</div>
            </div>
          </div>

          <div className="card">
            <h3 className="text-sm font-medium text-slate-500 uppercase tracking-wide">Dataset Images</h3>
            <p className="mt-3 text-4xl font-bold text-slate-900">{datasetStats?.total ?? 0}</p>
            <div className="mt-4 flex gap-2 flex-wrap">
              {Object.entries(datasetStats?.by_split ?? {}).map(([key, value]) => (
                <span key={key} className="text-xs bg-slate-100 text-slate-700 px-2 py-1 rounded">
                  {key}: {value}
                </span>
              ))}
            </div>
          </div>

          <div className="card">
            <h3 className="text-sm font-medium text-slate-500 uppercase tracking-wide">Total Scans</h3>
            <p className="mt-3 text-4xl font-bold text-blue-600">{analytics?.total_scans ?? 0}</p>
          </div>

          <div className="card">
            <h3 className="text-sm font-medium text-slate-500 uppercase tracking-wide">System Status</h3>
            <p className="mt-3 text-2xl font-semibold text-green-600">Online</p>
            <p className="mt-2 text-xs text-slate-500">All systems operational</p>
          </div>
        </div>

        {/* Dataset Composition */}
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">Dataset Distribution</h2>
              <p className="mt-1 text-sm text-slate-500">Disease labels in training set</p>
            </div>
            <span className="px-3 py-1 bg-emerald-100 text-emerald-700 text-xs font-medium rounded-full">Live</span>
          </div>

          <div className="mt-6 grid grid-cols-[240px_1fr] gap-8 items-center">
            <div className="h-56">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={Object.entries(datasetStats?.by_label ?? {}).map(([name, value]) => ({ name, value }))}
                    dataKey="value"
                    nameKey="name"
                    innerRadius={56}
                    outerRadius={86}
                    paddingAngle={2}
                  >
                    {Object.keys(datasetStats?.by_label ?? {}).map((key, index) => (
                      <Cell key={key} fill={palette[index % palette.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>

            <div className="space-y-4">
              {Object.entries(datasetStats?.by_label ?? {}).map(([key, value], index) => (
                <div key={key} className="flex items-center justify-between rounded-xl border bg-slate-50 px-4 py-3">
                  <div className="flex items-center gap-3">
                    <span className="h-3 w-3 rounded-full" style={{ backgroundColor: palette[index % palette.length] }} />
                    <span className="text-sm text-slate-700">{formatLabel(key)}</span>
                  </div>
                  <span className="text-sm font-medium text-slate-900">{value}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Charts Row */}
        <div className="grid gap-6 lg:grid-cols-2">
          {/* Top Disease */}
          <div className="card">
            <div className="flex items-center justify-between gap-4">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">Top Diseases</h2>
                <p className="mt-1 text-sm text-slate-500">Disease detection frequency</p>
              </div>
              <select
                value={diseaseInterval}
                onChange={(e) => setDiseaseInterval(e.target.value as TimeInterval)}
                className="px-3 py-2 border border-slate-200 rounded-lg bg-white text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-500"
              >
                <option value="daily">Daily</option>
                <option value="weekly">Weekly</option>
                <option value="monthly">Monthly</option>
              </select>
            </div>

            <div className="mt-6">
              {diseaseChartData.length > 0 ? (
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={diseaseChartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" angle={-45} textAnchor="end" height={80} fontSize={12} />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="scans" fill="#3b82f6" />
                  </BarChart>
                </ResponsiveContainer>
              ) : (
                <p className="py-8 text-center text-slate-500">No data available</p>
              )}
            </div>

            <button
              onClick={downloadPDF}
              className="mt-4 w-full px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition text-sm font-medium"
            >
              Download Report (PDF)
            </button>
          </div>

          {/* Users by Location */}
          <div className="card">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">Users by Location</h2>
              <p className="mt-1 text-sm text-slate-500">Geographic distribution</p>
            </div>

            <div className="mt-4">
              <label className="text-sm font-medium text-slate-700 block mb-2">Filter by Location:</label>
              <select
                value={selectedLocation || ''}
                onChange={(e) => setSelectedLocation(e.target.value || null)}
                className="w-full px-3 py-2 border border-slate-200 rounded-lg bg-white text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-500"
              >
                <option value="">All Locations</option>
                {availableLocations.map((loc) => (
                  <option key={loc} value={loc}>{loc}</option>
                ))}
              </select>
            </div>

            <div className="mt-6">
              {locationData.length > 0 ? (
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie 
                      data={locationData} 
                      dataKey="users" 
                      nameKey="name" 
                      cx="50%" 
                      cy="50%" 
                      outerRadius={100}
                    >
                      {locationData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={`hsl(${(index * 360) / locationData.length}, 70%, 50%)`} />
                      ))}
                    </Pie>
                    <Tooltip />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              ) : (
                <p className="py-8 text-center text-slate-500">No location data available</p>
              )}
            </div>
          </div>
        </div>

        {/* Latest Disease Scans with Pagination */}
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">Latest Disease Scans</h2>
              <p className="mt-1 text-sm text-slate-500">Recent detection history</p>
            </div>
            <div className="text-sm text-slate-500">
              Showing {(scansPage - 1) * scansPerPage + 1} to {Math.min(scansPage * scansPerPage, totalScans)} of {totalScans}
            </div>
          </div>

          <div ref={diseaseTableRef} className="mt-6 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-200">
                  <th className="px-4 py-3 text-left font-semibold text-slate-700">Disease</th>
                  <th className="px-4 py-3 text-left font-semibold text-slate-700">User</th>
                  <th className="px-4 py-3 text-left font-semibold text-slate-700">Location</th>
                  <th className="px-4 py-3 text-left font-semibold text-slate-700">Confidence</th>
                  <th className="px-4 py-3 text-left font-semibold text-slate-700">Timestamp</th>
                </tr>
              </thead>
              <tbody>
                {paginatedScans.map((scan, idx) => (
                  <tr key={idx} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="px-4 py-3">
                      <span className="inline-block rounded-full bg-slate-100 px-3 py-1 text-sm font-medium text-slate-700">
                        {formatLabel(scan.disease)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-slate-900">{scan.username}</td>
                    <td className="px-4 py-3 text-slate-600">{scan.location || 'N/A'}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <div className="h-2 w-16 overflow-hidden rounded-full bg-slate-200">
                          <div
                            className="h-full bg-emerald-500"
                            style={{ width: `${scan.confidence * 100}%` }}
                          />
                        </div>
                        <span className="text-sm font-medium text-slate-700">
                          {(scan.confidence * 100).toFixed(1)}%
                        </span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-slate-600">{formatPHTime(scan.timestamp)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination Controls */}
          <div className="mt-6 flex items-center justify-between">
            <div className="flex gap-2">
              <button
                onClick={() => setScansPage(Math.max(1, scansPage - 1))}
                disabled={scansPage === 1}
                className="px-3 py-2 border border-slate-200 rounded-lg text-sm font-medium hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                ← Previous
              </button>
              {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => (
                <button
                  key={page}
                  onClick={() => setScansPage(page)}
                  className={`px-3 py-2 rounded-lg text-sm font-medium ${
                    scansPage === page
                      ? 'bg-emerald-600 text-white'
                      : 'border border-slate-200 hover:bg-slate-50'
                  }`}
                >
                  {page}
                </button>
              ))}
              <button
                onClick={() => setScansPage(Math.min(totalPages, scansPage + 1))}
                disabled={scansPage === totalPages}
                className="px-3 py-2 border border-slate-200 rounded-lg text-sm font-medium hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Next →
              </button>
            </div>
            <div className="text-sm text-slate-600">
              Page {scansPage} of {totalPages}
            </div>
          </div>
        </div>

        {/* Disease Rankings Table */}
        <div className="card">
          <h2 className="text-lg font-semibold text-slate-900">Disease Rankings</h2>
          <p className="mt-1 text-sm text-slate-500">Overall ranking by detection frequency</p>

          <div className="mt-6 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-slate-200">
                  <th className="px-4 py-3 text-left font-semibold text-slate-700">Rank</th>
                  <th className="px-4 py-3 text-left font-semibold text-slate-700">Disease</th>
                  <th className="px-4 py-3 text-left font-semibold text-slate-700">Scans</th>
                  <th className="px-4 py-3 text-left font-semibold text-slate-700">Percentage</th>
                </tr>
              </thead>
              <tbody>
                {(analytics?.popular_diseases || []).map((disease) => {
                  const total = (analytics?.popular_diseases || []).reduce((sum, d) => sum + d.scan_count, 0);
                  const percentage = total > 0 ? ((disease.scan_count / total) * 100).toFixed(1) : '0.0';
                  return (
                    <tr key={disease.rank} className="border-b border-slate-100 hover:bg-slate-50">
                      <td className="px-4 py-3">
                        <span className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-emerald-100 text-sm font-bold text-emerald-700">
                          {disease.rank}
                        </span>
                      </td>
                      <td className="px-4 py-3 font-medium text-slate-900">{formatLabel(disease.disease_key)}</td>
                      <td className="px-4 py-3 text-slate-600">{disease.scan_count}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <div className="h-2 w-16 overflow-hidden rounded-full bg-slate-200">
                            <div
                              className="h-full bg-blue-500"
                              style={{ width: `${Math.min(parseFloat(percentage), 100)}%` }}
                            />
                          </div>
                          <span className="text-sm font-medium text-slate-700">{percentage}%</span>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}

'use client';

import { useEffect, useMemo, useState } from 'react';
import { apiRequest, authHeaders } from '@/lib/api';
import AdminLayout from '@/app/(admin)/layout';

interface DetectionTrainStartResponse {
  job_id: string;
  status: string;
}

interface TrainJobResponse {
  job_id: string;
  status: string;
  error?: string | null;
  model_version_id?: number | null;
  metrics?: Record<string, unknown> | null;
}

export default function TrainPage() {
  const [version, setVersion] = useState('v1.0.0-detect');
  const [epochs, setEpochs] = useState(50);
  const [imgsz, setImgsz] = useState(640);
  const [batch, setBatch] = useState(16);
  const [device, setDevice] = useState('');
  const [job, setJob] = useState<TrainJobResponse | null>(null);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const pollEnabled = useMemo(() => !!job && (job.status === 'queued' || job.status === 'running'), [job]);

  async function startTraining() {
    setError(null);
    setStarting(true);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const payload: Record<string, unknown> = { version: version.trim(), epochs, imgsz, batch };
      if (device.trim()) payload.device = device.trim();
      const res = await apiRequest<DetectionTrainStartResponse>('/admin/train/detection', {
        method: 'POST',
        headers: authHeaders(token),
        body: JSON.stringify(payload),
      });
      setJob({ job_id: res.job_id, status: res.status });
    } catch (e: any) {
      setError(e.message ?? 'Failed to start training');
    } finally {
      setStarting(false);
    }
  }

  async function refreshJob(jobId: string) {
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const res = await apiRequest<TrainJobResponse>(`/admin/train/jobs/${jobId}`, {
        headers: authHeaders(token),
      });
      setJob(res);
    } catch (e: any) {
      setError(e.message ?? 'Failed to fetch job status');
    }
  }

  useEffect(() => {
    if (!job?.job_id || !pollEnabled) return;
    const timer = setInterval(() => {
      void refreshJob(job.job_id);
    }, 2000);
    return () => clearInterval(timer);
  }, [job?.job_id, pollEnabled]);

  return (
    <AdminLayout>
      <div className="mx-auto max-w-[1200px] space-y-8">
        <div>
          <h1 className="page-title">Training</h1>
        </div>

        {error && <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

        <div className="grid grid-cols-[1.1fr_0.9fr] gap-6">
          <div className="card">
            <div className="section-kicker">Detection training</div>
            <h2 className="mt-2 section-title">Job configuration</h2>
            <div className="mt-6 grid grid-cols-2 gap-4">
              <div>
                <label className="field-label">Version name</label>
                <input className="input" value={version} onChange={(e) => setVersion(e.target.value)} />
              </div>
              <div>
                <label className="field-label">Device</label>
                <input className="input" value={device} onChange={(e) => setDevice(e.target.value)} placeholder="Optional, e.g. cpu or 0" />
              </div>
              <div>
                <label className="field-label">Epochs</label>
                <input className="input" type="number" value={epochs} onChange={(e) => setEpochs(Number(e.target.value))} />
              </div>
              <div>
                <label className="field-label">Image size</label>
                <input className="input" type="number" value={imgsz} onChange={(e) => setImgsz(Number(e.target.value))} />
              </div>
              <div>
                <label className="field-label">Batch size</label>
                <input className="input" type="number" value={batch} onChange={(e) => setBatch(Number(e.target.value))} />
              </div>
              <div>
                <label className="field-label">Base model</label>
                <div className="input flex items-center bg-slate-50 text-slate-600">backend/models/rice_disease.pt</div>
              </div>
            </div>
            <button className="btn-primary mt-6" onClick={() => void startTraining()} disabled={starting}>
              {starting ? 'Starting...' : 'Start training'}
            </button>
          </div>

          <div className="space-y-6">
            <div className="card">
              <div className="section-kicker">Job status</div>
              <h2 className="mt-2 section-title">Current run</h2>
              {!job ? (
                <div className="mt-6 text-sm text-slate-500">No training job has started yet.</div>
              ) : (
                <div className="mt-6 space-y-4 text-sm text-slate-600">
                  <div className="rounded-2xl border bg-slate-50 p-4">
                    <div className="stat-label">Job ID</div>
                    <div className="mt-2 font-mono text-xs text-slate-700">{job.job_id}</div>
                  </div>
                  <div className="rounded-2xl border bg-slate-50 p-4">
                    <div className="stat-label">Status</div>
                    <div className="mt-2 font-medium text-slate-900">{job.status}</div>
                  </div>
                  {job.error && <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-red-700">{job.error}</div>}
                  {job.status === 'succeeded' && (
                    <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-emerald-700">
                      Model version created{job.model_version_id ? ` (ID ${job.model_version_id})` : ''}.
                    </div>
                  )}
                </div>
              )}
            </div>

            {job?.metrics && (
              <div className="card">
                <div className="section-kicker">Metrics</div>
                <h2 className="mt-2 section-title">Raw output</h2>
                <pre className="mt-6 max-h-80 overflow-auto rounded-2xl bg-slate-50 p-4 text-xs leading-6 text-slate-600">
{JSON.stringify(job.metrics, null, 2)}
                </pre>
              </div>
            )}
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}

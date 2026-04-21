'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import AdminLayout from '@/app/(admin)/layout';
import { apiRequest, authHeaders } from '@/lib/api';

type DatasetItem = {
  id: number;
  label: string;
  split: string;
  image_url: string;
};

type Box = {
  id?: number;
  dataset_item_id: number;
  class_key: string;
  x_center: number;
  y_center: number;
  width: number;
  height: number;
  created_at: string;
};

type BoxInput = {
  x_center: number;
  y_center: number;
  width: number;
  height: number;
};

function clamp01(n: number) {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(1, n));
}

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

export default function AnnotateDatasetItemPage() {
  const params = useParams();
  const router = useRouter();
  const idRaw = params?.id;
  const datasetId = useMemo(() => {
    if (!idRaw) return null;
    const value = Number(Array.isArray(idRaw) ? idRaw[0] : idRaw);
    return Number.isFinite(value) ? value : null;
  }, [idRaw]);

  const [item, setItem] = useState<DatasetItem | null>(null);
  const [boxes, setBoxes] = useState<Box[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [aspectRatio, setAspectRatio] = useState(1);
  const imgRef = useRef<HTMLImageElement | null>(null);
  const [dragStart, setDragStart] = useState<{ x: number; y: number } | null>(null);
  const [dragEnd, setDragEnd] = useState<{ x: number; y: number } | null>(null);
  const dragStartRef = useRef<{ x: number; y: number } | null>(null);
  const dragEndRef = useRef<{ x: number; y: number } | null>(null);

  async function load() {
    if (!datasetId) return;
    setLoading(true);
    setError(null);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      const currentItem = await apiRequest<DatasetItem>(`/admin/datasets/${datasetId}`, { headers: authHeaders(token) });
      const currentBoxes = await apiRequest<Box[]>(`/admin/datasets/${datasetId}/annotations`, { headers: authHeaders(token) });
      setItem(currentItem);
      setBoxes(currentBoxes);
      setDragStart(null);
      setDragEnd(null);
    } catch (e: any) {
      setError(e.message ?? 'Failed to load annotations');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, [datasetId]);

  const livePreview: BoxInput | null = useMemo(() => {
    if (!dragStart || !dragEnd) return null;
    const left = Math.min(dragStart.x, dragEnd.x);
    const top = Math.min(dragStart.y, dragEnd.y);
    const right = Math.max(dragStart.x, dragEnd.x);
    const bottom = Math.max(dragStart.y, dragEnd.y);
    const width = right - left;
    const height = bottom - top;
    if (width < 0.01 || height < 0.01) return null;
    return { x_center: (left + right) / 2, y_center: (top + bottom) / 2, width, height };
  }, [dragEnd, dragStart]);

  function getNormFromPointerEvent(e: React.PointerEvent, target: HTMLElement) {
    const rect = target.getBoundingClientRect();
    return {
      x: clamp01((e.clientX - rect.left) / rect.width),
      y: clamp01((e.clientY - rect.top) / rect.height),
    };
  }

  async function save() {
    if (!datasetId || !item) return;
    setSaving(true);
    setError(null);
    try {
      const token = window.localStorage.getItem('admin_access_token') ?? '';
      await apiRequest(`/admin/datasets/${datasetId}/annotations`, {
        method: 'POST',
        headers: authHeaders(token),
        body: JSON.stringify({ boxes: boxes.map((box) => ({ x_center: box.x_center, y_center: box.y_center, width: box.width, height: box.height })) }),
      });
      await load();
    } catch (e: any) {
      setError(e.message ?? 'Failed to save annotations');
    } finally {
      setSaving(false);
    }
  }

  function startDrag(e: React.PointerEvent) {
    const point = getNormFromPointerEvent(e, e.currentTarget as HTMLElement);
    dragStartRef.current = point;
    dragEndRef.current = point;
    setDragStart(point);
    setDragEnd(point);
  }

  function moveDrag(e: React.PointerEvent) {
    if (!dragStartRef.current) return;
    const point = getNormFromPointerEvent(e, e.currentTarget as HTMLElement);
    dragEndRef.current = point;
    setDragEnd(point);
  }

  function endDrag() {
    if (!dragStartRef.current || !dragEndRef.current || !livePreview) {
      setDragStart(null);
      setDragEnd(null);
      dragStartRef.current = null;
      dragEndRef.current = null;
      return;
    }
    setBoxes((prev) => [
      ...prev,
      {
        dataset_item_id: datasetId ?? 0,
        class_key: item?.label ?? 'unknown',
        created_at: new Date().toISOString(),
        x_center: livePreview.x_center,
        y_center: livePreview.y_center,
        width: livePreview.width,
        height: livePreview.height,
      },
    ]);
    setDragStart(null);
    setDragEnd(null);
    dragStartRef.current = null;
    dragEndRef.current = null;
  }

  return (
    <AdminLayout>
      <div className="mx-auto max-w-[1240px] space-y-6">
        <div className="flex items-end justify-between gap-4">
          <div>
            <h1 className="page-title">Annotate dataset image</h1>
            <p className="page-subtitle">Draw bounding boxes for image #{datasetId}{item ? ` in ${formatLabel(item.label)}` : ''}.</p>
          </div>
          <div className="flex gap-3">
            <button className="btn-success" onClick={() => router.back()}>Back</button>
            <button className="btn-primary" onClick={() => void save()} disabled={saving || loading}>{saving ? 'Saving...' : 'Save annotations'}</button>
          </div>
        </div>

        {error && <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

        {loading ? (
          <div className="card text-sm text-slate-500">Loading...</div>
        ) : !item ? (
          <div className="card text-sm text-slate-500">Dataset item not found.</div>
        ) : (
          <div className="grid grid-cols-[1.1fr_0.9fr] gap-6">
            <div className="card">
              <div className="flex items-center justify-between">
                <div>
                  <div className="section-kicker">Canvas</div>
                  <h2 className="mt-2 section-title">Draw bounding boxes</h2>
                </div>
                <span className="badge badge-slate">{item.split}</span>
              </div>

              <div className="mt-6 relative w-full overflow-hidden rounded-2xl border bg-slate-50" style={{ aspectRatio: `${aspectRatio}` }}>
                <img
                  ref={imgRef}
                  src={item.image_url}
                  alt="dataset item"
                  className="absolute inset-0 h-full w-full object-contain"
                  onLoad={(e) => {
                    const image = e.currentTarget;
                    setAspectRatio(image.naturalWidth / Math.max(1, image.naturalHeight));
                  }}
                />
                <svg
                  viewBox="0 0 1 1"
                  preserveAspectRatio="none"
                  onPointerDown={startDrag}
                  onPointerMove={moveDrag}
                  onPointerUp={endDrag}
                  style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', touchAction: 'none' }}
                >
                  {boxes.map((box, index) => (
                    <rect
                      key={`${box.id ?? `tmp-${index}`}`}
                      x={box.x_center - box.width / 2}
                      y={box.y_center - box.height / 2}
                      width={box.width}
                      height={box.height}
                      fill="rgba(16, 185, 129, 0.18)"
                      stroke="#10b981"
                      strokeWidth={0.01}
                    />
                  ))}
                  {livePreview && (
                    <rect
                      x={livePreview.x_center - livePreview.width / 2}
                      y={livePreview.y_center - livePreview.height / 2}
                      width={livePreview.width}
                      height={livePreview.height}
                      fill="rgba(59, 130, 246, 0.18)"
                      stroke="#3b82f6"
                      strokeWidth={0.01}
                    />
                  )}
                </svg>
              </div>

              <p className="mt-4 text-sm leading-6 text-slate-500">
                Click and drag on the image to add a box. All saved boxes use the current dataset label.
              </p>
            </div>

            <div className="card">
              <div className="section-kicker">Boxes</div>
              <h2 className="mt-2 section-title">Current annotations</h2>
              <div className="mt-6 space-y-3">
                {boxes.length === 0 ? (
                  <div className="empty-state">No boxes yet.</div>
                ) : (
                  boxes.map((box, index) => (
                    <div key={`${box.id ?? `tmp-${index}`}`} className="rounded-xl border bg-slate-50 px-4 py-3">
                      <div className="flex items-center justify-between gap-3">
                        <div>
                          <div className="text-sm font-medium text-slate-900">Box {index + 1}</div>
                          <div className="mt-1 text-xs text-slate-500">
                            xc {box.x_center.toFixed(3)} | yc {box.y_center.toFixed(3)} | w {box.width.toFixed(3)} | h {box.height.toFixed(3)}
                          </div>
                        </div>
                        <button className="btn-success" onClick={() => setBoxes((prev) => prev.filter((_, currentIndex) => currentIndex !== index))}>Delete</button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </AdminLayout>
  );
}

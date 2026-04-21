from __future__ import annotations

import os
import json
import shutil
import threading
import time
import uuid
from dataclasses import dataclass
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import SessionLocal
from models import DatasetAnnotation, DatasetItem, ModelVersion, User
from routes.auth_routes import get_current_user
from schemas import DetectionTrainIn, TrainJobOut

router = APIRouter(prefix="/admin", tags=["Admin Training"])

_BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATASET_DIR = os.path.join(_BACKEND_DIR, "dataset_clean")
MODELS_DIR = os.path.join(_BACKEND_DIR, "models", "versions")
RUNS_DIR = os.path.join(_BACKEND_DIR, "training_runs", "detection")
YOLO_EXPORTS_DIR = os.path.join(_BACKEND_DIR, "yolo_exports", "detection")

os.makedirs(MODELS_DIR, exist_ok=True)
os.makedirs(RUNS_DIR, exist_ok=True)
os.makedirs(YOLO_EXPORTS_DIR, exist_ok=True)

# Keep a stable order that also matches your inference mapping expectations.
CLASS_KEYS = ["bacterial_blight", "brown_spot", "leaf_blast", "sheath_blight", "tungro"]
CLASS_TO_ID = {k: i for i, k in enumerate(CLASS_KEYS)}


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if (current_user.role or "user") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user


@dataclass
class _TrainJob:
    job_id: str
    status: str
    error: Optional[str] = None
    model_version_id: Optional[int] = None
    metrics: Optional[Dict[str, Any]] = None
    started_at: float = 0.0
    finished_at: Optional[float] = None


_JOBS: dict[str, _TrainJob] = {}
_JOBS_LOCK = threading.Lock()


def _clamp01(v: float) -> float:
    if v < 0.0:
        return 0.0
    if v > 1.0:
        return 1.0
    return v


def _export_yolo_dataset(db: Session, export_root: str) -> str:
    """
    Export the DB dataset into a YOLOv8 detection folder structure.

    Returns:
        Path to dataset yaml file.
    """

    splits = ["train", "val", "test"]
    export_images_dir = {s: os.path.join(export_root, "images", s) for s in splits}
    export_labels_dir = {s: os.path.join(export_root, "labels", s) for s in splits}

    for s in splits:
        os.makedirs(export_images_dir[s], exist_ok=True)
        os.makedirs(export_labels_dir[s], exist_ok=True)

    # Export only items that actually have at least one bounding box.
    items = db.query(DatasetItem).filter(DatasetItem.split.in_(splits)).all()

    exported_image_count = 0
    exported_by_split = {s: 0 for s in splits}
    for item in items:
        if item.label not in CLASS_TO_ID:
            # Ignore unexpected labels (keeps export robust).
            continue

        boxes = (
            db.query(DatasetAnnotation)
            .filter(DatasetAnnotation.dataset_item_id == item.id)
            .all()
        )
        if not boxes:
            continue

        if item.split not in export_images_dir:
            continue

        src = os.path.join(DATASET_DIR, item.image_filename)
        if not os.path.exists(src):
            continue

        stem, _ext = os.path.splitext(os.path.basename(item.image_filename))
        dst_img = os.path.join(export_images_dir[item.split], os.path.basename(item.image_filename))
        dst_lbl = os.path.join(export_labels_dir[item.split], f"{stem}.txt")

        shutil.copy2(src, dst_img)

        with open(dst_lbl, "w", encoding="utf-8") as f:
            class_id = CLASS_TO_ID[item.label]
            for b in boxes:
                # Ensure YOLO label values are within valid ranges.
                xc = _clamp01(float(b.x_center))
                yc = _clamp01(float(b.y_center))
                w = _clamp01(float(b.width))
                h = _clamp01(float(b.height))
                # Skip degenerate boxes.
                if w <= 0.0 or h <= 0.0:
                    continue
                f.write(f"{class_id} {xc:.6f} {yc:.6f} {w:.6f} {h:.6f}\n")

        exported_image_count += 1
        exported_by_split[item.split] += 1

    if exported_image_count == 0:
        raise HTTPException(
            status_code=400,
            detail="No annotated images found (add at least one bounding box per image).",
        )
    if exported_by_split["train"] == 0 or exported_by_split["val"] == 0:
        raise HTTPException(
            status_code=400,
            detail=(
                "Annotated dataset export requires at least one labeled image in both "
                "`train` and `val` splits."
            ),
        )

    # YOLO data.yaml uses paths relative to `path`.
    yaml_path = os.path.join(export_root, "dataset.yaml")
    yaml_text = (
        f"path: {export_root}\n"
        f"train: images/train\n"
        f"val: images/val\n"
        f"test: images/test\n"
        "names:\n"
    )
    for i, k in enumerate(CLASS_KEYS):
        yaml_text += f"  {i}: {k}\n"

    with open(yaml_path, "w", encoding="utf-8") as f:
        f.write(yaml_text)

    return yaml_path


def _parse_metrics(results_obj: Any) -> Dict[str, Any]:
    metrics: Dict[str, Any] = {}

    # Ultralytics typically exposes `results_dict` (keys depend on task).
    results_dict = getattr(results_obj, "results_dict", None) or getattr(results_obj, "metrics", None)
    if isinstance(results_dict, dict):
        metrics = results_dict
    elif hasattr(results_obj, "to_dict"):
        try:
            v = results_obj.to_dict()
            if isinstance(v, dict):
                metrics = v
        except Exception:
            pass
    return metrics


def _run_detection_training(job_id: str, payload: DetectionTrainIn):
    with _JOBS_LOCK:
        job = _JOBS[job_id]
        job.status = "running"

    # Import inside thread to avoid import-time issues at server startup.
    try:
        from ultralytics import YOLO  # type: ignore
    except Exception as e:
        _set_job_error(job_id, f"Missing ML dependency: {e!r}")
        return

    db = SessionLocal()
    try:
        # Prevent duplicate versions.
        existing = db.query(ModelVersion).filter(ModelVersion.version == payload.version).first()
        if existing:
            _set_job_error(job_id, f"Model version '{payload.version}' already exists.")
            return

        export_root = os.path.join(YOLO_EXPORTS_DIR, job_id)
        os.makedirs(export_root, exist_ok=True)

        yaml_path = _export_yolo_dataset(db, export_root)

        base_model_path = os.path.join(_BACKEND_DIR, "models", "rice_disease.pt")
        if not os.path.exists(base_model_path):
            _set_job_error(job_id, f"Base model not found at '{base_model_path}'.")
            return

        # Ultralytics training run directory.
        run_name = f"exp_{job_id}"

        model = YOLO(base_model_path)

        # Note: We keep params conservative; adjust later from the UI.
        train_kwargs: Dict[str, Any] = {
            "data": yaml_path,
            "epochs": payload.epochs,
            "imgsz": payload.imgsz,
            "batch": payload.batch,
            "project": RUNS_DIR,
            "name": run_name,
        }
        if payload.device:
            train_kwargs["device"] = payload.device

        results = model.train(**train_kwargs)
        metrics = _parse_metrics(results)

        # Guess best/last weights locations.
        run_root = os.path.join(RUNS_DIR, run_name)
        best_path = os.path.join(run_root, "weights", "best.pt")
        last_path = os.path.join(run_root, "weights", "last.pt")
        weight_path = best_path if os.path.exists(best_path) else last_path

        if not os.path.exists(weight_path):
            _set_job_error(job_id, "Training finished, but weights were not found.")
            return

        dest_model_path = os.path.join(MODELS_DIR, f"{payload.version}_detect_best.pt")
        shutil.copy2(weight_path, dest_model_path)

        # Common metric keys for detection. If they don't exist, values remain null.
        map_score = metrics.get("metrics/mAP50-95(B)") or metrics.get("metrics/mAP50-95") or metrics.get("metrics/mAP50(B)")
        precision = metrics.get("metrics/precision(B)") or metrics.get("metrics/precision")
        recall = metrics.get("metrics/recall(B)") or metrics.get("metrics/recall")
        f1_score = metrics.get("metrics/F1(B)") or metrics.get("metrics/F1") or metrics.get("metrics/f1_score")

        new_version = ModelVersion(
            version=payload.version,
            file_path=dest_model_path,
            is_active=False,
            map_score=map_score if isinstance(map_score, (int, float)) else None,
            precision=precision if isinstance(precision, (int, float)) else None,
            recall=recall if isinstance(recall, (int, float)) else None,
            f1_score=f1_score if isinstance(f1_score, (int, float)) else None,
            classes=json.dumps(CLASS_KEYS),
            description=f"Detection fine-tune job {job_id}",
        )
        db.add(new_version)
        db.commit()
        db.refresh(new_version)

        with _JOBS_LOCK:
            job = _JOBS[job_id]
            job.status = "succeeded"
            job.model_version_id = new_version.id
            job.metrics = metrics
            job.finished_at = time.time()

    except HTTPException as he:
        _set_job_error(job_id, str(he.detail))
    except Exception as e:
        _set_job_error(job_id, f"Training failed: {e!r}")
    finally:
        try:
            db.close()
        except Exception:
            pass


def _set_job_error(job_id: str, error: str):
    with _JOBS_LOCK:
        if job_id in _JOBS:
            job = _JOBS[job_id]
            job.status = "failed"
            job.error = error
            job.finished_at = time.time()


@router.post("/train/detection")
def start_detection_training(
    payload: DetectionTrainIn,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    # Basic guard: avoid starting multiple long trainings at once by default.
    with _JOBS_LOCK:
        running = [j for j in _JOBS.values() if j.status == "running"]
        if running:
            raise HTTPException(status_code=409, detail="A training job is already running.")

        job_id = str(uuid.uuid4())
        _JOBS[job_id] = _TrainJob(job_id=job_id, status="queued", started_at=time.time())

    t = threading.Thread(target=_run_detection_training, args=(job_id, payload), daemon=True)
    t.start()

    return {"job_id": job_id, "status": "queued"}


@router.get("/train/jobs/{job_id}", response_model=TrainJobOut)
def get_train_job(job_id: str, _: User = Depends(require_admin)):
    with _JOBS_LOCK:
        job = _JOBS.get(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        return TrainJobOut(
            job_id=job.job_id,
            status=job.status,
            error=job.error,
            model_version_id=job.model_version_id,
            metrics=job.metrics,
        )


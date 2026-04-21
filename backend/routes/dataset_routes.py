from __future__ import annotations

import os
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from sqlalchemy.orm import Session

from database import SessionLocal
from models import DatasetItem, Disease, User
from routes.auth_routes import get_current_user
from schemas import DatasetItemOut
from services.activity_log import log_activity


router = APIRouter(prefix="/admin", tags=["Admin Datasets"])

_BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATASET_DIR = os.path.join(_BACKEND_DIR, "dataset_clean")
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".jfif"}
ALLOWED_SPLITS = {"train", "val", "test"}

os.makedirs(DATASET_DIR, exist_ok=True)


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


@router.get("/datasets", response_model=list[DatasetItemOut])
def list_datasets(
    q: str | None = None,
    label: str | None = None,
    split: str | None = None,
    limit: int = 50,
    offset: int = 0,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    limit = max(1, min(limit, 200))
    offset = max(0, offset)

    query = db.query(DatasetItem)
    if label:
        query = query.filter(DatasetItem.label == label)
    if split:
        query = query.filter(DatasetItem.split == split)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(DatasetItem.label.ilike(like))

    items = (
        query.order_by(DatasetItem.created_at.desc())
        .limit(limit)
        .offset(offset)
        .all()
    )
    return items


@router.post("/datasets/upload", response_model=DatasetItemOut)
async def upload_dataset_item(
    request: Request,
    label: str,
    split: str = "train",
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    label = (label or "").strip()
    if not label:
        raise HTTPException(status_code=400, detail="label is required")

    split = (split or "train").strip().lower()
    if split not in ALLOWED_SPLITS:
        raise HTTPException(status_code=400, detail=f"split must be one of {sorted(ALLOWED_SPLITS)}")

    ext = os.path.splitext(image.filename or "")[1].lower()
    is_image_ct = bool(image.content_type) and image.content_type.startswith("image/")
    is_image_ext = ext in ALLOWED_EXT
    if not (is_image_ct or is_image_ext):
        raise HTTPException(status_code=400, detail="File must be an image")

    filename = f"{uuid4().hex}{ext or '.jpg'}"
    file_path = os.path.join(DATASET_DIR, filename)

    with open(file_path, "wb") as f:
        f.write(await image.read())

    base_url = str(request.base_url).rstrip("/")
    image_url = f"{base_url}/dataset/{filename}"

    item = DatasetItem(
        image_filename=filename,
        image_url=image_url,
        label=label,
        split=split,
        uploaded_by_user_id=current_user.id,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    log_activity(
        db,
        user_id=current_user.id,
        action="dataset.upload",
        detail={"label": label, "split": split, "image_filename": filename},
    )
    return item


@router.delete("/datasets/{item_id}")
def delete_dataset_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    item = db.query(DatasetItem).filter(DatasetItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Dataset item not found")

    file_path = os.path.join(DATASET_DIR, item.image_filename)
    if os.path.exists(file_path):
        try:
            os.remove(file_path)
        except Exception:
            pass

    db.delete(item)
    db.commit()
    log_activity(
        db,
        user_id=current_user.id,
        action="dataset.delete",
        detail={"dataset_item_id": item_id, "image_filename": item.image_filename},
    )
    return {"message": "Deleted"}


@router.get("/datasets/stats")
def dataset_stats(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    # Keep response simple for Flutter/admin-web consumption.
    # Include every active disease key so the dashboard can render zero-count
    # classes instead of dropping them from the chart entirely.
    rows = db.query(DatasetItem.label, DatasetItem.split).all()
    disease_keys = [
        key
        for (key,) in db.query(Disease.key)
        .filter(Disease.is_active == True)
        .order_by(Disease.id.asc())
        .all()
    ]
    total = len(rows)
    by_label: dict[str, int] = {key: 0 for key in disease_keys}
    by_split: dict[str, int] = {}
    for l, s in rows:
        by_label[l] = by_label.get(l, 0) + 1
        by_split[s] = by_split.get(s, 0) + 1
    return {"total": total, "by_label": by_label, "by_split": by_split}


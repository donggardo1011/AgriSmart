from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import SessionLocal
from models import DatasetAnnotation, DatasetItem, User
from routes.auth_routes import get_current_user
from schemas import DatasetAnnotationIn, DatasetAnnotationOut, DatasetItemOut

router = APIRouter(prefix="/admin", tags=["Admin Dataset Annotations"])


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


@router.get("/datasets/{item_id}", response_model=DatasetItemOut)
def get_dataset_item(item_id: int, db: Session = Depends(get_db), _: User = Depends(require_admin)):
    item = db.query(DatasetItem).filter(DatasetItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Dataset item not found")
    return item


@router.get(
    "/datasets/{item_id}/annotations",
    response_model=List[DatasetAnnotationOut],
)
def list_annotations(item_id: int, db: Session = Depends(get_db), _: User = Depends(require_admin)):
    item = db.query(DatasetItem).filter(DatasetItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Dataset item not found")

    boxes = (
        db.query(DatasetAnnotation)
        .filter(DatasetAnnotation.dataset_item_id == item_id)
        .order_by(DatasetAnnotation.created_at.asc())
        .all()
    )
    return boxes


@router.post(
    "/datasets/{item_id}/annotations",
    response_model=List[DatasetAnnotationOut],
)
def replace_annotations(
    item_id: int,
    payload: DatasetAnnotationIn,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    item = db.query(DatasetItem).filter(DatasetItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Dataset item not found")

    # Replace behavior: delete existing boxes and insert the submitted ones.
    db.query(DatasetAnnotation).filter(DatasetAnnotation.dataset_item_id == item_id).delete(
        synchronize_session=False
    )

    new_rows: list[DatasetAnnotation] = []
    class_key = item.label

    for b in payload.boxes:
        new_rows.append(
            DatasetAnnotation(
                dataset_item_id=item_id,
                class_key=class_key,
                x_center=b.x_center,
                y_center=b.y_center,
                width=b.width,
                height=b.height,
            )
        )

    if new_rows:
        db.add_all(new_rows)

    db.commit()

    boxes = (
        db.query(DatasetAnnotation)
        .filter(DatasetAnnotation.dataset_item_id == item_id)
        .order_by(DatasetAnnotation.created_at.asc())
        .all()
    )
    return boxes


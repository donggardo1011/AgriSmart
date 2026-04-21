from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Form
from typing import List, Optional
import os
import shutil
import json
from datetime import datetime
from sqlalchemy.orm import Session
from database import SessionLocal
from models import ModelVersion
from schemas import ModelVersionOut
from routes.auth_routes import get_current_user

router = APIRouter(prefix="/model", tags=["Model Management"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Directory for model versions
MODELS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "models", "versions")
os.makedirs(MODELS_DIR, exist_ok=True)
BASE_MODEL_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "models",
    "rice_disease.pt",
)
DEFAULT_CLASSES = json.dumps(
    ["bacterial_blight", "brown_spot", "leaf_blast", "sheath_blight", "tungro"]
)


def ensure_base_model_registered(db: Session) -> ModelVersion | None:
    if not os.path.exists(BASE_MODEL_PATH):
        return None

    base = (
        db.query(ModelVersion)
        .filter(ModelVersion.file_path == BASE_MODEL_PATH)
        .first()
    )
    if base is None:
        base = (
            db.query(ModelVersion)
            .filter(ModelVersion.version == "v1.0.0-base")
            .first()
        )
    if base is None:
        base = ModelVersion(
            version="v1.0.0-base",
            file_path=BASE_MODEL_PATH,
            is_active=False,
            map_score=0.85,
            precision=0.82,
            recall=0.88,
            f1_score=0.85,
            classes=DEFAULT_CLASSES,
            description="Base preloaded rice disease model",
        )
        db.add(base)
        db.commit()
        db.refresh(base)
    else:
        updated = False
        if base.file_path != BASE_MODEL_PATH:
            base.file_path = BASE_MODEL_PATH
            updated = True
        if base.classes != DEFAULT_CLASSES:
            base.classes = DEFAULT_CLASSES
            updated = True
        if not base.description:
            base.description = "Base preloaded rice disease model"
            updated = True
        if updated:
            db.commit()
            db.refresh(base)

    has_active = db.query(ModelVersion).filter(ModelVersion.is_active == True).first()  # noqa: E712
    if has_active is None:
        base.is_active = True
        db.commit()
        db.refresh(base)

    return base


def get_active_model_record(db: Session) -> ModelVersion | None:
    ensure_base_model_registered(db)
    return (
        db.query(ModelVersion)
        .filter(ModelVersion.is_active == True)  # noqa: E712
        .first()
    )

@router.get("/status", response_model=ModelVersionOut)
def get_model_status(db: Session = Depends(get_db)):
    active_model = get_active_model_record(db)
    if not active_model:
        # Return a dummy/default if none in DB yet
        return {
            "id": 0,
            "version": "v1.0.0-default",
            "file_path": BASE_MODEL_PATH,
            "is_active": True,
            "map_score": 0.85,
            "precision": 0.82,
            "recall": 0.88,
            "f1_score": 0.85,
            "classes": DEFAULT_CLASSES,
            "description": "Default pre-loaded model",
            "created_at": datetime.utcnow()
        }
    return active_model

@router.get("/versions", response_model=List[ModelVersionOut])
def list_versions(db: Session = Depends(get_db)):
    ensure_base_model_registered(db)
    return db.query(ModelVersion).order_by(ModelVersion.created_at.desc()).all()

@router.post("/upload")
async def upload_model(
    version: str = Form(...),
    description: Optional[str] = Form(None),
    map_score: Optional[float] = Form(None),
    precision: Optional[float] = Form(None),
    recall: Optional[float] = Form(None),
    f1_score: Optional[float] = Form(None),
    classes: Optional[str] = Form(None), # JSON string
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    # current_user = Depends(get_current_user) # Uncomment for auth
):
    # Check if version already exists
    existing = db.query(ModelVersion).filter(ModelVersion.version == version).first()
    if existing:
        raise HTTPException(status_code=400, detail="Version already exists")

    # Save file
    filename = f"{version}_{file.filename}"
    file_path = os.path.join(MODELS_DIR, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Save to DB
    new_version = ModelVersion(
        version=version,
        file_path=file_path,
        description=description,
        map_score=map_score,
        precision=precision,
        recall=recall,
        f1_score=f1_score,
        classes=classes,
        is_active=False
    )
    db.add(new_version)
    db.commit()
    db.refresh(new_version)
    
    return new_version

@router.post("/activate/{version_id}")
def activate_model(version_id: int, db: Session = Depends(get_db)):
    # Deactivate all
    db.query(ModelVersion).update({ModelVersion.is_active: False})
    
    # Activate target
    target = db.query(ModelVersion).filter(ModelVersion.id == version_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Model version not found")
    
    target.is_active = True
    db.commit()
    return {"message": f"Model {target.version} activated"}

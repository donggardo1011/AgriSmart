from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import SessionLocal
from models import Disease, User
from routes.auth_routes import get_current_user

router = APIRouter(prefix="/api", tags=["Diseases"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _require_auth(user: User | None) -> User:
    if user is None:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return user


@router.get("/diseases")
def list_diseases(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_auth(current_user)
    rows = (
        db.query(Disease)
        .filter(Disease.is_active == True)  # Only show active diseases
        .order_by(Disease.display_name.asc())
        .all()
    )
    return [
        {
            "id": d.id,
            "key": d.key,
            "display_name": d.display_name,
            "causal_agent": d.causal_agent if hasattr(d, 'causal_agent') and d.causal_agent else "",
            "severity": d.severity,
            "urgency": d.urgency,
            "explanation_en": d.explanation,
            "symptoms_summary_en": d.symptoms_summary_en if hasattr(d, 'symptoms_summary_en') and d.symptoms_summary_en else "",
            "prevention_summary_en": d.prevention_summary_en if hasattr(d, 'prevention_summary_en') and d.prevention_summary_en else "",
            "treatment_summary_en": d.treatment_summary_en if hasattr(d, 'treatment_summary_en') and d.treatment_summary_en else "",
            "image_url": d.image_url if hasattr(d, 'image_url') and d.image_url else "",
            "is_active": d.is_active,
            "created_at": d.created_at,
        }
        for d in rows
    ]

@router.put("/diseases/{disease_id}")
def update_disease(
    disease_id: int,
    data: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = _require_auth(current_user)
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    disease = db.query(Disease).filter(Disease.id == disease_id).first()
    if not disease:
        raise HTTPException(status_code=404, detail="Disease not found")
    
    # Update fields
    if "display_name" in data: disease.display_name = data["display_name"]
    if "severity" in data: disease.severity = data["severity"]
    if "urgency" in data: disease.urgency = data["urgency"]
    if "explanation" in data: disease.explanation = data["explanation"]
    if "is_active" in data: disease.is_active = data["is_active"]
    
    db.commit()
    db.refresh(disease)
    return disease


@router.get("/diseases/count")
def count_diseases(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_auth(current_user)
    n = (
        db.query(Disease)
        .filter(Disease.is_active == True)  # noqa: E712
        .count()
    )
    return {"count": int(n)}


def disease_from_db(db: Session, key: str) -> dict[str, Any] | None:
    d = db.query(Disease).filter(Disease.key == key, Disease.is_active == True).first()  # noqa: E712
    if not d:
        return None

    def _loads(s: str | None) -> list[str]:
        if not s:
            return []
        try:
            v = json.loads(s)
            return v if isinstance(v, list) else []
        except Exception:
            return []

    # Parse symptoms and causes
    symptoms = _loads(d.symptoms)
    causes = _loads(d.causes)
    
    # If database entry is incomplete (empty symptoms or causes), return None to use DISEASE_KB instead
    if not symptoms or not causes:
        return None

    return {
        "display": d.display_name,
        "severity": d.severity,
        "urgency": d.urgency,
        "explanation": d.explanation,
        "symptoms": symptoms,
        "causes": causes,
        "prevention": _loads(d.prevention),
        "treatment_plan": _loads(d.treatment_plan),
        "fertilizer_guidance": _loads(d.fertilizer_guidance),
        "next_steps": _loads(d.next_steps),
        "when_to_contact": _loads(d.when_to_contact),
    }


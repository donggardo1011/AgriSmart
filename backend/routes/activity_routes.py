from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel

from database import SessionLocal
from models import User, ActivityLog
from routes.auth_routes import get_current_user

router = APIRouter(prefix="/activities", tags=["Activities"])

# DB Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Schemas
class ActivityIn(BaseModel):
    action: str
    description: Optional[str] = None
    details: Optional[dict] = None

class ActivityOut(BaseModel):
    id: int
    action: str
    detail: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

# Endpoints
@router.post("/", response_model=ActivityOut, status_code=201)
async def create_activity(
    payload: ActivityIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Log an activity for the current user"""
    import json
    
    detail_str = None
    if payload.details:
        detail_str = json.dumps(payload.details, ensure_ascii=False)
    elif payload.description:
        detail_str = payload.description
    
    activity = ActivityLog(
        user_id=current_user.id,
        action=payload.action,
        detail=detail_str,
        created_at=datetime.utcnow()
    )
    db.add(activity)
    db.commit()
    db.refresh(activity)
    return activity

@router.get("/", response_model=List[ActivityOut])
async def list_activities(
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get activities for the current user"""
    activities = db.query(ActivityLog)\
        .filter(ActivityLog.user_id == current_user.id)\
        .order_by(ActivityLog.created_at.desc())\
        .limit(limit)\
        .offset(offset)\
        .all()
    return activities

@router.get("/stats", response_model=dict)
async def get_activity_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get activity statistics for the current user"""
    total = db.query(ActivityLog).filter(ActivityLog.user_id == current_user.id).count()
    
    activities = db.query(ActivityLog.action).filter(
        ActivityLog.user_id == current_user.id
    ).all()
    
    action_counts = {}
    for activity in activities:
        action = activity[0]
        action_counts[action] = action_counts.get(action, 0) + 1
    
    return {
        "total_activities": total,
        "actions": action_counts
    }

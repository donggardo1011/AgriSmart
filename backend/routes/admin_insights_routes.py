from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import joinedload
from sqlalchemy.orm import Session

from database import SessionLocal
from models import ActivityLog, User
from routes.auth_routes import get_current_user
from schemas import ActivityLogOut, AdminUserOut, is_user_online


router = APIRouter(prefix="/admin", tags=["Admin Insights"])


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


@router.get("/users/count")
def admin_user_count(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    total = db.query(User).count()
    active = db.query(User).filter(User.is_active == True).count()  # noqa: E712
    admins = db.query(User).filter(User.role == "admin").count()
    return {"total": total, "active": active, "admins": admins}


@router.get("/users", response_model=list[AdminUserOut])
def admin_list_users(
    q: str | None = None,
    limit: int = 50,
    offset: int = 0,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    limit = max(1, min(limit, 200))
    offset = max(0, offset)

    query = db.query(User)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter((User.username.ilike(like)) | (User.email.ilike(like)))

    users = (
        query.order_by(User.created_at.desc())
        .limit(limit)
        .offset(offset)
        .all()
    )
    
    # Build response with computed status
    result = []
    for user in users:
        user_out = AdminUserOut(
            id=user.id,
            username=user.username,
            email=user.email,
            location=user.location,
            role=user.role,
            is_active=user.is_active,
            last_activity_at=user.last_activity_at,
            status="online" if is_user_online(user.last_activity_at) else "offline",
            created_at=user.created_at,
        )
        result.append(user_out)
    
    return result


@router.get("/activities", response_model=list[ActivityLogOut])
def admin_list_activities(
    user_id: int | None = None,
    action: str | None = None,
    limit: int = 100,
    offset: int = 0,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    limit = max(1, min(limit, 500))
    offset = max(0, offset)

    query = db.query(ActivityLog).options(joinedload(ActivityLog.user))
    if user_id is not None:
        query = query.filter(ActivityLog.user_id == user_id)
    if action:
        query = query.filter(ActivityLog.action == action)

    rows = (
        query.order_by(ActivityLog.created_at.desc())
        .limit(limit)
        .offset(offset)
        .all()
    )

    # Attach identity fields for admin UX (keep user_id for traceability)
    out: list[ActivityLogOut] = []
    for r in rows:
        out.append(
            ActivityLogOut(
                id=r.id,
                user_id=r.user_id,
                username=(r.user.username if r.user else None),
                email=(r.user.email if r.user else None),
                location=r.location,
                action=r.action,
                detail=r.detail,
                created_at=r.created_at,
            )
        )
    return out


@router.post("/users/{user_id}/role")
def admin_change_user_role(
    user_id: int,
    role: str,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_admin),
):
    """Change user role (admin or user)"""
    
    # Validate role
    if role not in ["admin", "user"]:
        raise HTTPException(status_code=400, detail="Invalid role. Must be 'admin' or 'user'")
    
    # Get user to update
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Prevent admin from removing their own admin role
    if user.id == current_admin.id and role != "admin":
        raise HTTPException(status_code=400, detail="Cannot remove your own admin role")
    
    old_role = user.role
    user.role = role
    db.commit()
    db.refresh(user)
    
    # Log the role change
    from services.activity_log import log_activity
    log_activity(
        db,
        user_id=current_admin.id,
        action="admin.user_role_change",
        detail={"target_user": user.username, "old_role": old_role, "new_role": role},
        location=current_admin.location
    )
    
    return {
        "success": True,
        "message": f"User {user.username} role changed from '{old_role}' to '{role}'",
        "user_id": user.id,
        "new_role": user.role
    }


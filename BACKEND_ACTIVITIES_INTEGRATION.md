# Backend Integration - Activities Endpoint

## Required FastAPI Implementation

If you don't have an activities tracking endpoint yet, add this to your backend:

### 1. Add Activity Schema (`backend/schemas.py`)

```python
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class ActivityCreate(BaseModel):
    action: str
    description: str
    timestamp: datetime
    details: Optional[Dict[str, Any]] = None

class ActivityResponse(BaseModel):
    id: int
    user_id: int
    action: str
    description: str
    timestamp: datetime
    details: Optional[Dict[str, Any]]
    created_at: datetime

    class Config:
        orm_mode = True
```

### 2. Add Activity Model (`backend/models.py`)

```python
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
import json

class Activity(Base):
    __tablename__ = "activities"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    action = Column(String(255), nullable=False)  # e.g., "scan.create", "dashboard.view"
    description = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
    details = Column(JSON, nullable=True)  # Store extra data as JSON
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationship
    user = relationship("User", back_populates="activities")

    def __repr__(self):
        return f"<Activity(id={self.id}, user_id={self.user_id}, action={self.action})>"
```

### 3. Update User Model (`backend/models.py`)

```python
class User(Base):
    # ... existing fields ...
    
    # Add this relationship
    activities = relationship("Activity", back_populates="user", cascade="all, delete-orphan")
```

### 4. Add Activity Routes (`backend/routes/activity_routes.py`)

Create new file: `backend/routes/activity_routes.py`

```python
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from datetime import datetime

from schemas import ActivityCreate, ActivityResponse
from models import Activity, User
from database import SessionLocal, get_db
from auth import get_current_user

router = APIRouter(prefix="/activities", tags=["activities"])

@router.post("", response_model=ActivityResponse, status_code=status.HTTP_201_CREATED)
def create_activity(
    activity: ActivityCreate,
    current_user: User = Depends(get_current_user),
    db: SessionLocal = Depends(get_db)
):
    """
    Create a new activity log for the current user.
    
    Called when user logs in after being offline to sync pending activities.
    """
    try:
        db_activity = Activity(
            user_id=current_user.id,
            action=activity.action,
            description=activity.description,
            timestamp=activity.timestamp,
            details=activity.details
        )
        db.add(db_activity)
        db.commit()
        db.refresh(db_activity)
        return db_activity
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to create activity: {str(e)}"
        )

@router.get("", response_model=List[ActivityResponse])
def list_activities(
    skip: int = 0,
    limit: int = 100,
    action: str = None,
    current_user: User = Depends(get_current_user),
    db: SessionLocal = Depends(get_db)
):
    """
    Get all activities for the current user.
    
    Optional filter by action type (e.g., "scan.create", "dashboard.view")
    """
    query = db.query(Activity).filter(Activity.user_id == current_user.id)
    
    if action:
        query = query.filter(Activity.action == action)
    
    return query.order_by(Activity.created_at.desc()).offset(skip).limit(limit).all()

@router.get("/{activity_id}", response_model=ActivityResponse)
def get_activity(
    activity_id: int,
    current_user: User = Depends(get_current_user),
    db: SessionLocal = Depends(get_db)
):
    """
    Get a specific activity by ID.
    
    User can only view their own activities.
    """
    activity = db.query(Activity).filter(
        Activity.id == activity_id,
        Activity.user_id == current_user.id
    ).first()
    
    if not activity:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Activity not found"
        )
    
    return activity

@router.get("/stats/summary")
def get_activity_stats(
    current_user: User = Depends(get_current_user),
    db: SessionLocal = Depends(get_db)
):
    """
    Get activity statistics for the current user.
    """
    activities = db.query(Activity).filter(Activity.user_id == current_user.id).all()
    
    action_counts = {}
    for activity in activities:
        action_counts[activity.action] = action_counts.get(activity.action, 0) + 1
    
    return {
        "total_activities": len(activities),
        "by_action": action_counts,
        "last_activity": activities[0].timestamp if activities else None
    }
```

### 5. Register Routes in Main (`backend/main.py`)

```python
from fastapi import FastAPI
from routes.activity_routes import router as activity_router

app = FastAPI()

# ... existing routes ...

app.include_router(activity_router)
```

### 6. Database Migration

Run this to create the activities table:

```bash
# Using Alembic (if configured)
alembic revision --autogenerate -m "Add activities table"
alembic upgrade head

# Or manually if using SQLite:
# The User model change automatically includes the relationship
# Run: python backend/database.py to recreate
```

## API Usage

### Create Activity (from frontend when syncing)
```
POST /activities
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "action": "scan.create",
  "description": "Created scan: Leaf Blast",
  "timestamp": "2024-04-12T10:35:00Z",
  "details": {
    "image_file": "path/to/image.jpg",
    "disease_detected": "Leaf Blast",
    "confidence": "0.95"
  }
}

Response 201:
{
  "id": 123,
  "user_id": 5,
  "action": "scan.create",
  "description": "Created scan: Leaf Blast",
  "timestamp": "2024-04-12T10:35:00Z",
  "details": {...},
  "created_at": "2024-04-12T10:35:00Z"
}
```

### Get User's Activities
```
GET /activities?skip=0&limit=50
Authorization: Bearer <access_token>

Response:
[
  {
    "id": 123,
    "user_id": 5,
    "action": "scan.create",
    "description": "Created scan: Leaf Blast",
    ...
  },
  ...
]
```

### Filter by Action
```
GET /activities?action=scan.create
Authorization: Bearer <access_token>

Response: Activities matching "scan.create"
```

### Get Activity Stats
```
GET /activities/stats/summary
Authorization: Bearer <access_token>

Response:
{
  "total_activities": 45,
  "by_action": {
    "scan.create": 12,
    "dashboard.view": 15,
    "settings.update": 8,
    "auth.guest_access": 10
  },
  "last_activity": "2024-04-12T10:35:00Z"
}
```

## Admin Features (Optional)

Add these endpoints for admin dashboard to track user activities:

```python
@router.get("/admin/all", response_model=List[ActivityResponse])
def admin_get_all_activities(
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 100,
    db: SessionLocal = Depends(get_db)
):
    """
    Get all activities system-wide. Requires admin role.
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can view all activities"
        )
    
    return db.query(Activity).order_by(Activity.created_at.desc()).offset(skip).limit(limit).all()

@router.get("/admin/user/{user_id}", response_model=List[ActivityResponse])
def admin_get_user_activities(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: SessionLocal = Depends(get_db)
):
    """
    Get activities for a specific user. Requires admin role.
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can view user activities"
        )
    
    return db.query(Activity).filter(Activity.user_id == user_id).all()
```

## Testing the Endpoint

```bash
# Using curl
curl -X POST http://localhost:8000/activities \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "scan.create",
    "description": "Test scan",
    "timestamp": "2024-04-12T10:35:00Z",
    "details": {"test": true}
  }'

# Using Python
import requests
import json
from datetime import datetime

token = "YOUR_ACCESS_TOKEN"
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

data = {
    "action": "scan.create",
    "description": "Test activity",
    "timestamp": datetime.utcnow().isoformat() + "Z",
    "details": {"test": True}
}

response = requests.post(
    "http://localhost:8000/activities",
    headers=headers,
    json=data
)

print(response.status_code)
print(response.json())
```

## Summary

1. Add `Activity` model and `ActivityCreate` schema
2. Update `User` model with activities relationship
3. Create `activity_routes.py` with CRUD endpoints
4. Register routes in `main.py`
5. Run database migration
6. Test endpoints with curl/Postman

The frontend will automatically sync activities to this endpoint when:
- User logs in after being offline
- Auto-sync timer triggers (60-second intervals)
- User manually triggers sync

All pending activities will be sent as POST requests to `/activities`!

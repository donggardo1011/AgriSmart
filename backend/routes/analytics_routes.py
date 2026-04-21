from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func, desc, and_
from datetime import datetime, timedelta
from typing import List, Dict, Any
import json

from database import SessionLocal
from models import User, Prediction, ActivityLog, DiseaseRanking, Disease
from routes.auth_routes import get_current_user
from schemas import (
    AnalyticsDashboardOut, 
    MonthlyDiseaseRankingOut, 
    DiseaseRankingOut,
    ReportGenerateIn
)


router = APIRouter(prefix="/analytics", tags=["Analytics"])


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


@router.get("/dashboard", response_model=AnalyticsDashboardOut)
def get_analytics_dashboard(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get comprehensive analytics dashboard for admin"""
    
    # Total stats
    total_users = db.query(User).count()
    active_users = db.query(User).filter(User.is_active == True).count()  # noqa: E712
    total_admins = db.query(User).filter(User.role == "admin").count()
    total_scans = db.query(Prediction).count()
    
    # Latest diseases (recent scans)
    latest_diseases = db.query(
        Prediction.label,
        Prediction.confidence,
        Prediction.created_at,
        User.username,
        User.location,
        func.count(Prediction.id).over(partition_by=Prediction.label).label('count')
    ).join(User, Prediction.user_id == User.id).order_by(desc(Prediction.created_at)).limit(10).all()
    
    latest_diseases_list = [
        {
            "disease": item[0],
            "confidence": item[1],
            "timestamp": item[2].isoformat() if item[2] else None,
            "username": item[3],
            "location": item[4]
        }
        for item in latest_diseases
    ]
    
    # Top diseases this month
    now = datetime.utcnow()
    current_year = now.year
    current_month = now.month
    
    popular_diseases_query = db.query(
        Disease.key,
        Disease.display_name,
        func.count(Prediction.id).label('scan_count')
    ).join(
        Prediction, Prediction.label == Disease.key
    ).filter(
        func.extract('year', Prediction.created_at) == current_year,
        func.extract('month', Prediction.created_at) == current_month
    ).group_by(
        Disease.key,
        Disease.display_name
    ).order_by(desc(func.count(Prediction.id))).limit(10).all()
    
    popular_diseases = [
        DiseaseRankingOut(
            disease_key=item[0],
            disease_name=item[1],
            scan_count=item[2],
            rank=idx + 1,
            location=None
        )
        for idx, item in enumerate(popular_diseases_query)
    ]
    
    # Locations count
    locations_count_query = db.query(
        User.location,
        func.count(User.id).label('count')
    ).filter(
        User.location != None  # noqa: E712
    ).group_by(User.location).all()
    
    locations_count = {
        item[0]: item[1] 
        for item in locations_count_query
    }
    
    return AnalyticsDashboardOut(
        total_users=total_users,
        active_users=active_users,
        total_admins=total_admins,
        total_scans=total_scans,
        latest_diseases=latest_diseases_list,
        popular_diseases=popular_diseases,
        locations_count=locations_count
    )


@router.get("/diseases/monthly-ranking", response_model=List[MonthlyDiseaseRankingOut])
def get_monthly_disease_ranking(
    year: int | None = None,
    month: int | None = None,
    location: str | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get disease rankings for a specific month"""
    
    if year is None:
        year = datetime.utcnow().year
    if month is None:
        month = datetime.utcnow().month
    
    # Query predictions for the given month
    query = db.query(
        Disease.key.label('disease_key'),
        Disease.display_name.label('disease_name'),
        func.count(Prediction.id).label('scan_count'),
        Prediction.created_at
    ).join(
        Prediction, Prediction.label == Disease.key
    ).filter(
        func.extract('year', Prediction.created_at) == year,
        func.extract('month', Prediction.created_at) == month
    )
    
    if location:
        query = query.join(User, Prediction.user_id == User.id).filter(
            User.location == location
        )
    
    results = query.group_by(
        Disease.key,
        Disease.display_name,
        Prediction.created_at
    ).order_by(desc(func.count(Prediction.id))).all()
    
    # Group by disease and rank
    disease_scans = {}
    for row in results:
        key = row[0]
        if key not in disease_scans:
            disease_scans[key] = {
                'name': row[1],
                'count': 0
            }
        disease_scans[key]['count'] += 1
    
    # Sort and rank
    ranked = sorted(
        disease_scans.items(),
        key=lambda x: x[1]['count'],
        reverse=True
    )
    
    rankings = [
        DiseaseRankingOut(
            disease_key=key,
            disease_name=value['name'],
            scan_count=value['count'],
            rank=idx + 1,
            location=location
        )
        for idx, (key, value) in enumerate(ranked)
    ]
    
    return [
        MonthlyDiseaseRankingOut(
            year=year,
            month=month,
            rankings=rankings
        )
    ]


@router.get("/diseases/top-by-location")
def get_top_diseases_by_location(
    limit: int = 10,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get top diseases grouped by user location"""
    
    now = datetime.utcnow()
    current_year = now.year
    current_month = now.month
    
    results = db.query(
        User.location,
        Prediction.label.label('disease_key'),
        Disease.display_name,
        func.count(Prediction.id).label('scan_count')
    ).join(
        Prediction, Prediction.user_id == User.id
    ).join(
        Disease, Prediction.label == Disease.key
    ).filter(
        func.extract('year', Prediction.created_at) == current_year,
        func.extract('month', Prediction.created_at) == current_month,
        User.location != None  # noqa: E712
    ).group_by(
        User.location,
        Prediction.label,
        Disease.display_name
    ).order_by(
        User.location,
        desc(func.count(Prediction.id))
    ).all()
    
    # Organize by location
    by_location = {}
    for row in results:
        location = row[0]
        if location not in by_location:
            by_location[location] = []
        
        if len(by_location[location]) < limit:
            by_location[location].append({
                "disease_key": row[1],
                "disease_name": row[2],
                "scan_count": row[3]
            })
    
    return by_location


@router.get("/users/by-location")
def get_users_by_location(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get user distribution by location"""
    
    results = db.query(
        User.location,
        func.count(User.id).label('count'),
        func.sum(func.cast(User.is_active, type_=func.Integer)).label('active_count')
    ).filter(
        User.location != None  # noqa: E712
    ).group_by(User.location).order_by(desc(func.count(User.id))).all()
    
    return [
        {
            "location": row[0],
            "total_users": row[1],
            "active_users": row[2] or 0
        }
        for row in results
    ]


@router.post("/reports/generate")
def generate_report(
    payload: ReportGenerateIn,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Generate analytics report"""
    
    # Query base data
    if payload.report_type == "monthly":
        year = payload.year
        month = payload.month or datetime.utcnow().month
    elif payload.report_type == "quarterly":
        year = payload.year
        month = None
    elif payload.report_type == "yearly":
        year = payload.year
        month = None
    else:
        year = payload.year
        month = payload.month
    
    # Get diseases data for the period
    query = db.query(
        Disease.key,
        Disease.display_name,
        func.count(Prediction.id).label('scan_count'),
        func.avg(Prediction.confidence).label('avg_confidence')
    ).join(
        Prediction, Prediction.label == Disease.key
    ).filter(
        func.extract('year', Prediction.created_at) == year
    )
    
    if month:
        query = query.filter(func.extract('month', Prediction.created_at) == month)
    
    disease_stats = query.group_by(
        Disease.key,
        Disease.display_name
    ).order_by(desc(func.count(Prediction.id))).all()
    
    # Get location stats if requested
    location_stats = None
    if payload.include_locations:
        loc_query = db.query(
            User.location,
            func.count(Prediction.id).label('scans'),
            func.count(func.distinct(User.id)).label('unique_users')
        ).join(
            Prediction, Prediction.user_id == User.id
        ).filter(
            func.extract('year', Prediction.created_at) == year,
            User.location != None  # noqa: E712
        )
        
        if month:
            loc_query = loc_query.filter(func.extract('month', Prediction.created_at) == month)
        
        location_stats = loc_query.group_by(User.location).all()
    
    # Compile report
    report_data = {
        "metadata": {
            "report_type": payload.report_type,
            "year": year,
            "month": month,
            "generated_at": datetime.utcnow().isoformat(),
            "format": payload.format
        },
        "diseases": [
            {
                "key": row[0],
                "name": row[1],
                "total_scans": row[2],
                "avg_confidence": float(row[3] or 0)
            }
            for row in disease_stats
        ],
        "summary": {
            "total_diseases_detected": len(disease_stats),
            "total_scans": sum(row[2] for row in disease_stats)
        }
    }
    
    if location_stats:
        report_data["locations"] = [
            {
                "location": row[0],
                "total_scans": row[1],
                "unique_users": row[2]
            }
            for row in location_stats
        ]
    
    return {
        "status": "success",
        "report": report_data,
        "format": payload.format
    }


@router.get("/activity-heatmap")
def get_activity_heatmap(
    days: int = 30,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get activity heatmap for the last N days"""
    
    start_date = datetime.utcnow() - timedelta(days=days)
    
    results = db.query(
        func.date(ActivityLog.created_at).label('date'),
        func.extract('hour', ActivityLog.created_at).label('hour'),
        func.count(ActivityLog.id).label('activity_count')
    ).filter(
        ActivityLog.created_at >= start_date
    ).group_by(
        func.date(ActivityLog.created_at),
        func.extract('hour', ActivityLog.created_at)
    ).order_by(
        func.date(ActivityLog.created_at),
        func.extract('hour', ActivityLog.created_at)
    ).all()
    
    return [
        {
            "date": str(row[0]),
            "hour": int(row[1]),
            "activity_count": row[2]
        }
        for row in results
    ]

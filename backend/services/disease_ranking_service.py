"""Service for updating disease ranking statistics"""

from sqlalchemy.orm import Session
from datetime import datetime
from sqlalchemy import func, desc
from models import DiseaseRanking, Prediction, Disease


def update_disease_ranking(db: Session, disease_key: str, user_location: str | None = None) -> None:
    """Update disease ranking when a prediction is made"""
    
    now = datetime.utcnow()
    year = now.year
    month = now.month
    
    try:
        # Check if ranking exists for this disease/month/location
        existing_rank = db.query(DiseaseRanking).filter(
            DiseaseRanking.disease_key == disease_key,
            DiseaseRanking.year == year,
            DiseaseRanking.month == month,
            DiseaseRanking.location == user_location
        ).first()
        
        if existing_rank:
            existing_rank.scan_count += 1
            existing_rank.updated_at = now
        else:
            # Create new ranking entry
            rank_entry = DiseaseRanking(
                disease_key=disease_key,
                year=year,
                month=month,
                location=user_location,
                scan_count=1,
                created_at=now,
                updated_at=now
            )
            db.add(rank_entry)
        
        db.commit()
        
        # Update ranks for this month/location
        _update_ranks(db, year, month, user_location)
        
    except Exception as e:
        print(f"Error updating disease ranking: {repr(e)}")
        db.rollback()


def _update_ranks(db: Session, year: int, month: int, location: str | None = None) -> None:
    """Update rank values for disease rankings"""
    
    try:
        query = db.query(DiseaseRanking).filter(
            DiseaseRanking.year == year,
            DiseaseRanking.month == month
        )
        
        if location:
            query = query.filter(DiseaseRanking.location == location)
        
        rankings = query.order_by(desc(DiseaseRanking.scan_count)).all()
        
        for idx, ranking in enumerate(rankings, 1):
            ranking.rank = idx
        
        db.commit()
        
    except Exception as e:
        print(f"Error updating ranks: {repr(e)}")
        db.rollback()


def get_disease_rankings_for_month(
    db: Session, 
    year: int, 
    month: int, 
    location: str | None = None,
    limit: int = 10
) -> list:
    """Get top diseases for a given month"""
    
    query = db.query(DiseaseRanking).filter(
        DiseaseRanking.year == year,
        DiseaseRanking.month == month
    )
    
    if location:
        query = query.filter(DiseaseRanking.location == location)
    
    return query.order_by(DiseaseRanking.rank).limit(limit).all()

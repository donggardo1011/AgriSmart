from sqlalchemy import Column, Integer, String, DateTime, Boolean
from datetime import datetime
from database import Base

from sqlalchemy import ForeignKey, Float, Text
from sqlalchemy.orm import relationship
from sqlalchemy import DateTime
from datetime import datetime

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    location = Column(String, nullable=True)  # User's location (province/city/region)
    role = Column(String, nullable=False, default="user")  # "user" | "admin"

    # password is nullable because Google users may not have local password
    password = Column(String, nullable=True)

    google_sub = Column(String, unique=True, index=True, nullable=True)

    is_active = Column(Boolean, default=True)
    last_activity_at = Column(DateTime, nullable=True)  # Track when user was last active
    created_at = Column(DateTime, default=datetime.utcnow)

    # password reset fields
    reset_token_hash = Column(String, nullable=True)
    reset_token_expires_at = Column(DateTime, nullable=True)

class RefreshSession(Base):
    __tablename__ = "refresh_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)

    refresh_token_hash = Column(String, unique=True, index=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    revoked_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")

class Prediction(Base):
    __tablename__ = "predictions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)

    image_filename = Column(String, nullable=False)  # store just filename
    image_url = Column(String, nullable=False)

    label = Column(String, nullable=False)
    confidence = Column(Float, nullable=False)
    advice = Column(Text, nullable=False)
    detections = Column(Text, nullable=True)  # JSON string of all detections

    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")

class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    action = Column(String, nullable=False)
    detail = Column(Text, nullable=True)
    location = Column(String, nullable=True)  # User's location when activity occurred
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")

class Disease(Base):
    __tablename__ = "diseases"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String, unique=True, nullable=False, index=True)
    display_name = Column(String, nullable=False)
    causal_agent = Column(String, nullable=True)

    severity = Column(String, nullable=False)
    urgency = Column(String, nullable=False)
    explanation = Column(Text, nullable=False)
    symptoms_summary_en = Column(Text, nullable=True)
    prevention_summary_en = Column(Text, nullable=True)
    treatment_summary_en = Column(Text, nullable=True)
    image_url = Column(String, nullable=True)

    symptoms = Column(Text, nullable=False)            # JSON string
    causes = Column(Text, nullable=False)              # JSON string
    prevention = Column(Text, nullable=False)          # JSON string
    treatment_plan = Column(Text, nullable=False)      # JSON string
    fertilizer_guidance = Column(Text, nullable=False) # JSON string
    next_steps = Column(Text, nullable=True)           # JSON string
    when_to_contact = Column(Text, nullable=True)      # JSON string

    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class DatasetItem(Base):
    __tablename__ = "dataset_items"

    id = Column(Integer, primary_key=True, index=True)

    image_filename = Column(String, nullable=False)
    image_url = Column(String, nullable=False)

    label = Column(String, nullable=False, index=True)
    split = Column(String, nullable=False, default="train")  # train|val|test

    uploaded_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    uploaded_by = relationship("User")


class DatasetAnnotation(Base):
    """
    Normalized YOLO-format bounding boxes stored per uploaded dataset image.

    Coordinates are normalized to [0..1] relative to the original image dimensions:
    x_center, y_center, width, height.
    """

    __tablename__ = "dataset_annotations"

    id = Column(Integer, primary_key=True, index=True)

    dataset_item_id = Column(
        Integer,
        ForeignKey("dataset_items.id"),
        index=True,
        nullable=False,
    )

    # Store the class key (e.g. "brown_spot") for robustness when exporting YOLO labels.
    class_key = Column(String, nullable=False, index=True)

    x_center = Column(Float, nullable=False)
    y_center = Column(Float, nullable=False)
    width = Column(Float, nullable=False)
    height = Column(Float, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow)

    dataset_item = relationship("DatasetItem")

class ModelVersion(Base) :
    __tablename__ = "model_versions"

    id = Column(Integer, primary_key=True, index=True)
    version = Column(String, unique=True, index=True, nullable=False)
    file_path = Column(String, nullable=False)
    is_active = Column(Boolean, default=False)
    
    # Evaluation metrics
    map_score = Column(Float, nullable=True)
    precision = Column(Float, nullable=True)
    recall = Column(Float, nullable=True)
    f1_score = Column(Float, nullable=True)
    
    # Metadata
    classes = Column(Text, nullable=True) # JSON list of class names
    description = Column(Text, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)


class DiseaseRanking(Base):
    __tablename__ = "disease_rankings"

    id = Column(Integer, primary_key=True, index=True)
    disease_key = Column(String, ForeignKey("diseases.key"), nullable=False, index=True)
    year = Column(Integer, nullable=False)
    month = Column(Integer, nullable=False)  # 1-12
    scan_count = Column(Integer, default=0)  # Number of times scanned by users
    location = Column(String, nullable=True)  # Track per location
    rank = Column(Integer, nullable=True)  # Rank within the month (1 = most popular)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    disease = relationship("Disease")
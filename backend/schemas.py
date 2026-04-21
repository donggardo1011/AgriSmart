from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta

# Helper function to determine online status (online if active in last 30 minutes)
def is_user_online(last_activity_at: Optional[datetime]) -> bool:
    if last_activity_at is None:
        return False
    cutoff = datetime.utcnow() - timedelta(minutes=30)
    return last_activity_at >= cutoff

class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    location: Optional[str] = None  # User's location (province/city/region)
    recaptcha_token: str

class UserLogin(BaseModel):
    username: str
    password: str
    recaptcha_token: str

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserOut(BaseModel):
    id: int
    username: str
    email: EmailStr
    role: str
    location: Optional[str] = None
    last_activity_at: Optional[datetime] = None
    status: str = "offline"  # "online" or "offline"

    class Config:
        from_attributes = True
    
    @property
    def get_status(self) -> str:
        return "online" if is_user_online(self.last_activity_at) else "offline"

class ForgotPasswordIn(BaseModel):
    email: EmailStr
    recaptcha_token: str

class ResetPasswordIn(BaseModel):
    token: str
    new_password: str = Field(min_length=6, max_length=128)

class ResetPasswordOtpVerifyIn(BaseModel):
    email: EmailStr
    otp_code: str  # 6-digit code
    new_password: str = Field(min_length=6, max_length=128)

class ChangePasswordIn(BaseModel):
    old_password: str = Field(min_length=6, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

class GoogleLoginIn(BaseModel):
    id_token: str
    recaptcha_token: str

class LoginOut(TokenOut):
    # Keep as-is for Swagger clarity. Refresh token is stored in HttpOnly cookie (not returned).
    pass

class DetectionBox(BaseModel):
    """Individual detection bounding box"""
    label: str
    confidence: float
    class_name: str
    left: float
    top: float
    right: float
    bottom: float

class PredictionOut(BaseModel):
    id: int
    label: str
    confidence: float
    advice: str
    image_url: str
    created_at: datetime
    detections: Optional[List[DetectionBox]] = None

    class Config:
        from_attributes = True

class ChatbotIn(BaseModel):
    disease: str
    message: Optional[str] = None # optional questions from user
    language: Optional[str] = "english"

class ChatbotOut(BaseModel):
    disease: str
    severity: str
    urgency: str
    explanation: str
    symptoms: List[str]
    causes: List[str]
    prevention: List[str]
    treatment_plan: List[str]
    fertilizer_guidance: List[str]
    next_steps: List[str]
    when_to_contact: List[str]
    reply: str #chat bot style response text


class DatasetItemOut(BaseModel):
    id: int
    label: str
    split: str
    image_url: str
    created_at: datetime

    class Config:
        from_attributes = True


class DatasetAnnotationBox(BaseModel):
    # Normalized YOLO coordinates in range [0..1]
    x_center: float = Field(ge=0.0, le=1.0)
    y_center: float = Field(ge=0.0, le=1.0)
    width: float = Field(gt=0.0, le=1.0)
    height: float = Field(gt=0.0, le=1.0)


class DatasetAnnotationIn(BaseModel):
    # For your current setup, all boxes in an image can share the dataset item's label.
    boxes: List[DatasetAnnotationBox]


class DatasetAnnotationOut(BaseModel):
    id: int
    dataset_item_id: int
    class_key: str
    x_center: float
    y_center: float
    width: float
    height: float
    created_at: datetime

    class Config:
        from_attributes = True


class AdminUserOut(BaseModel):
    id: int
    username: str
    email: str  # Use str instead of EmailStr to allow .local domains
    location: Optional[str] = None
    role: str
    is_active: bool | None = False  # Allow None with default False
    last_activity_at: Optional[datetime] = None
    status: str = "offline"  # "online" or "offline"
    created_at: datetime | None = None  # Allow None for older records

    class Config:
        from_attributes = True
    
    @property
    def get_status(self) -> str:
        return "online" if is_user_online(self.last_activity_at) else "offline"


class ActivityLogOut(BaseModel):
    id: int
    user_id: int | None
    username: str | None = None
    email: str | None = None
    location: str | None = None
    action: str
    detail: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

class ModelVersionOut(BaseModel):
    id: int
    version: str
    file_path: str
    is_active: bool
    map_score: Optional[float]
    precision: Optional[float]
    recall: Optional[float]
    f1_score: Optional[float]
    classes: Optional[str]
    description: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class DetectionTrainIn(BaseModel):
    # Where to store the new fine-tuned model when training finishes.
    version: str = Field(min_length=1, max_length=200)

    epochs: int = Field(default=50, ge=1, le=1000)
    imgsz: int = Field(default=640, ge=32, le=4096)
    batch: int = Field(default=16, ge=1, le=512)

    # Ultralytics supports a variety of device formats; keep it optional.
    device: Optional[str] = None


class TrainJobOut(BaseModel):
    job_id: str
    status: str
    error: Optional[str] = None

    # Set on success
    model_version_id: Optional[int] = None
    metrics: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True


# Analytics schemas
class DiseaseRankingOut(BaseModel):
    disease_key: str
    disease_name: str
    scan_count: int
    rank: int
    location: Optional[str] = None

    class Config:
        from_attributes = True


class AnalyticsDashboardOut(BaseModel):
    total_users: int
    active_users: int
    total_admins: int
    total_scans: int
    latest_diseases: List[Dict[str, Any]]  # Recent scans
    popular_diseases: List[DiseaseRankingOut]  # Top diseases this month
    locations_count: Dict[str, int]  # Users per location


class MonthlyDiseaseRankingOut(BaseModel):
    year: int
    month: int
    rankings: List[DiseaseRankingOut]


class ReportGenerateIn(BaseModel):
    format: str = Field(default="pdf")  # pdf, csv, json
    report_type: str  # monthly, quarterly, yearly, custom
    year: int = Field(default=datetime.now().year)
    month: Optional[int] = None
    include_locations: bool = True
    filters: Optional[Dict[str, Any]] = None

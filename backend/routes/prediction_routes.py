from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, Request, Form
from sqlalchemy.orm import Session
from uuid import uuid4
import os
import json
import subprocess
from typing import Optional, Tuple
from PIL import Image
from database import SessionLocal
from models import Prediction, User
from schemas import PredictionOut, ChatbotIn, ChatbotOut
from routes.auth_routes import get_current_user
from routes.disease_routes import disease_from_db
from routes.model_routes import get_active_model_record, BASE_MODEL_PATH
from services.activity_log import log_activity
from services.disease_ranking_service import update_disease_ranking

router = APIRouter(prefix="/api", tags=["Predictions"])

_BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
UPLOAD_DIR = os.path.join(_BACKEND_DIR, "uploads")
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".jfif", ".heic"}

os.makedirs(UPLOAD_DIR, exist_ok=True)

def _convert_heic_to_jpeg(heic_path: str) -> str:
    """Convert HEIC image to JPEG using available tools. Returns path to JPEG file."""
    jpeg_path = heic_path.rsplit(".", 1)[0] + ".jpg"
    
    try:
        # Try using PIL directly (works if HEIC codec is available)
        with Image.open(heic_path) as img:
            # Convert RGBA to RGB if necessary
            if img.mode == "RGBA":
                rgb_img = Image.new("RGB", img.size, (255, 255, 255))
                rgb_img.paste(img, mask=img.split()[3] if len(img.split()) == 4 else None)
                rgb_img.save(jpeg_path, "JPEG", quality=95)
            else:
                img.save(jpeg_path, "JPEG", quality=95)
            os.remove(heic_path)
            return jpeg_path
    except Exception as pil_error:
        # Fallback: Try using ImageMagick if available
        try:
            subprocess.run(
                ["magick", "convert", heic_path, "-quality", "95", jpeg_path],
                check=True,
                capture_output=True,
                timeout=10
            )
            os.remove(heic_path)
            return jpeg_path
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            pass
    
    # If both methods fail, raise error
    raise RuntimeError(
        f"Cannot convert HEIC file. Pillow could not process it, and ImageMagick is not installed. "
        f"Please convert your image to JPG or PNG format first."
    )




def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

_MODEL = None
_MODEL_ERROR: Optional[str] = None
_MODEL_SOURCE_PATH: Optional[str] = None

# Override with env var, e.g. AI_MODEL_PATH=path/to/rice_disease.pt
AI_MODEL_PATH = os.getenv("AI_MODEL_PATH", BASE_MODEL_PATH)

SUPPORTED_DISEASES = {
    "bacterial_blight",
    "brown_spot",
    "leaf_blast",
    "sheath_blight",
    "tungro",
}

def _normalize_disease(d: str) -> str:
    return (d or "").strip().lower().replace(" ", "_")

def _map_class_name_to_key(name: str) -> Optional[str]:
    n = (name or "").strip().lower()
    # Brown spot variants
    if ("brown" in n and "spot" in n) or ("narrow" in n and "brown" in n and "spot" in n):
        return "brown_spot"
    if "sheath" in n:
        return "sheath_blight"
    if "tungro" in n:
        return "tungro"
    # Only map bacterial leaf blight (not sheath blight)
    if ("bacterial" in n) and ("blight" in n):
        return "bacterial_blight"
    if "blast" in n:
        return "leaf_blast"
    return None

def _resolve_inference_model_path() -> str:
    db = SessionLocal()
    try:
        active = get_active_model_record(db)
        if active and active.file_path and os.path.exists(active.file_path):
            return active.file_path
    finally:
        db.close()

    return AI_MODEL_PATH


def _ensure_model_loaded():
    global _MODEL, _MODEL_ERROR, _MODEL_SOURCE_PATH
    resolved_model_path = _resolve_inference_model_path()
    if (
        _MODEL is not None
        and _MODEL_ERROR is None
        and _MODEL_SOURCE_PATH == resolved_model_path
    ):
        return

    _MODEL = None
    _MODEL_ERROR = None
    _MODEL_SOURCE_PATH = resolved_model_path

    try:
        from ultralytics import YOLO  # type: ignore
    except Exception:
        _MODEL_ERROR = (
            "Missing ML dependency 'ultralytics'. "
            "Install it in backend venv: pip install ultralytics"
        )
        return

    if not os.path.exists(resolved_model_path):
        _MODEL_ERROR = (
            f"Model file not found at '{resolved_model_path}'. "
            "Place it there or set AI_MODEL_PATH env var."
        )
        return

    try:
        _MODEL = YOLO(resolved_model_path)
    except Exception as e:
        _MODEL_ERROR = f"Failed to load model: {e!r}"

def _build_advice_for_key(disease_key: str) -> str:
    kb = DISEASE_KB.get(disease_key) or {}
    display = kb.get("display", disease_key.replace("_", " ").title())
    severity = kb.get("severity", "Unknown")
    urgency = kb.get("urgency", "N/A")
    explanation = kb.get("explanation", "")
    treatment_plan = kb.get("treatment_plan", []) or []
    prevention = kb.get("prevention", []) or []
    fertilizer = kb.get("fertilizer_guidance", []) or []

    def first_or(items, default):
        return items[0] if items else default

    return (
        f"Disease: {display}\n"
        f"Severity: {severity} | Urgency: {urgency}\n\n"
        f"{explanation}\n\n"
        "Top actions:\n"
        f"1) {first_or(treatment_plan, 'Monitor and keep records')}\n"
        f"2) {first_or(prevention, 'Maintain good field sanitation')}\n"
        f"3) {first_or(fertilizer, 'Use balanced fertilization')}\n"
    )

# Minimum confidence thresholds for valid detection
# STRICT THRESHOLDS: Only accept very high confidence to avoid false positives
MIN_CONFIDENCE_THRESHOLD = 0.72  # 72% minimum to be considered valid
STRICTER_CONFIDENCE_THRESHOLD = 0.80  # 80% for disease diagnosis

def _validate_rice_leaf_detected(best_conf: float, custom_threshold: Optional[float] = None) -> Tuple[bool, str]:
    """
    Validate if a rice leaf was actually detected in the image.
    
    Args:
        best_conf: The best confidence score from the model
        custom_threshold: Optional custom threshold to override defaults (0.0-1.0)
    
    Returns:
        Tuple[bool, str]: (is_valid, message)
        - (True, ""): Valid rice leaf detected
        - (False, message): No rice leaf or low confidence
    """
    # Use custom threshold if provided, otherwise use defaults
    primary_threshold = custom_threshold if custom_threshold is not None else MIN_CONFIDENCE_THRESHOLD
    secondary_threshold = custom_threshold if custom_threshold is not None else STRICTER_CONFIDENCE_THRESHOLD
    
    if best_conf < primary_threshold:
        return (
            False,
            f"Image contains people, objects, or unclear rice detection ({best_conf*100:.1f}% confidence).\n\n"
            "Please try:\n"
            "• Remove people from the photo\n"
            "• Focus ONLY on rice leaves\n"
            "• Take a clearer, well-lit photo\n"
            "• Get closer to the leaf\n\n"
            "This app specifically analyzes individual rice leaves, not group photos.\n"
            "Please upload a clean photo with only rice leaves."
        )
    
    if best_conf < secondary_threshold and custom_threshold is None:
        return (
            False,
            f"Detection confidence is too low ({best_conf*100:.1f}%).\n\n"
            "Please try:\n"
            "• Take a clearer, well-lit photo\n"
            "• Get closer to the rice leaf with visible symptoms\n"
            "• Ensure good lighting\n"
            "• Remove any people or objects from the frame\n"
        )
    
    return (True, "")


def ai_predict(image_path: str, custom_threshold: Optional[float] = None) -> Tuple[str, float, str, list]:
    _ensure_model_loaded()
    if _MODEL_ERROR:
        raise RuntimeError(_MODEL_ERROR)
    if _MODEL is None:
        raise RuntimeError("Model is not loaded")

    # Ultralytics path handling on Windows can be picky with backslashes.
    model_path = os.path.abspath(image_path).replace("\\", "/")

    try:
        with Image.open(image_path) as img:
            image_width, image_height = img.size
    except Exception:
        image_width, image_height = 640, 640

    if image_width <= 0:
        image_width = 640
    if image_height <= 0:
        image_height = 640

    results = _MODEL(model_path, verbose=False)
    if not results:
        raise RuntimeError("No inference results")

    r0 = results[0]

    # Classification models provide r0.probs
    if hasattr(r0, "probs") and r0.probs is not None:
        probs = r0.probs
        top1 = int(probs.top1)
        conf = float(probs.top1conf)
        name = r0.names.get(top1, str(top1)) if hasattr(r0, "names") else str(top1)
        print("AI DEBUG (cls):", "raw_name=", str(name), "conf=", conf)
        
        # Validate rice leaf presence
        is_valid, validation_msg = _validate_rice_leaf_detected(conf, custom_threshold)
        if not is_valid:
            return (
                "invalid_image",
                0.0,
                validation_msg,
                []
            )
        
        key = _map_class_name_to_key(str(name)) or _normalize_disease(str(name))
        if key not in SUPPORTED_DISEASES:
            key = "brown_spot"
        return key, conf, _build_advice_for_key(key), []

    # Detection models provide r0.boxes with cls/conf
    if hasattr(r0, "boxes") and r0.boxes is not None and len(r0.boxes) > 0:
        # Use custom threshold if provided, otherwise use default
        threshold = custom_threshold if custom_threshold is not None else MIN_CONFIDENCE_THRESHOLD
        boxes = r0.boxes
        detections = []
        best_conf = -1.0
        best_key = "brown_spot"
        
        # Extract ALL detections with bounding boxes
        for i in range(len(boxes)):
            conf = float(boxes.conf[i])
            cls_id = int(boxes.cls[i])
            
            # Only include detections with HIGHER confidence threshold
            if conf < threshold:
                continue
            
            name = r0.names.get(cls_id, str(cls_id)) if hasattr(r0, "names") else str(cls_id)
            key = _map_class_name_to_key(str(name)) or _normalize_disease(str(name))
            if key not in SUPPORTED_DISEASES:
                key = "brown_spot"
            
            # Get bounding box coordinates (x1, y1, x2, y2)
            box = boxes.xyxy[i] if hasattr(boxes, 'xyxy') else None
            left = float(box[0]) if box is not None else 0
            top = float(box[1]) if box is not None else 0
            right = float(box[2]) if box is not None else image_width
            bottom = float(box[3]) if box is not None else image_height

            left = left / image_width
            top = top / image_height
            right = right / image_width
            bottom = bottom / image_height

            detections.append({
                "label": key,
                "confidence": conf,
                "class_name": str(name),
                "left": left,
                "top": top,
                "right": right,
                "bottom": bottom,
            })
            
            # Track best detection for main response
            if conf > best_conf:
                best_conf = conf
                best_key = key
        
        print(f"AI DEBUG (det): found {len(detections)} detections above threshold, best={best_key} conf={best_conf}")
        
        threshold = custom_threshold if custom_threshold is not None else MIN_CONFIDENCE_THRESHOLD
        if detections and best_conf >= threshold:
            # Validate rice leaf presence before returning diagnosis
            is_valid, validation_msg = _validate_rice_leaf_detected(best_conf, custom_threshold)
            if not is_valid:
                return (
                    "invalid_image",
                    0.0,
                    validation_msg,
                    []
                )
            return best_key, best_conf, _build_advice_for_key(best_key), detections
        else:
            # No valid detections found
            return (
                "invalid_image",
                0.0,
                "No valid rice leaf detection. Please ensure:\n"
                "• The image shows ONLY rice leaves\n"
                "• No people or other objects in the frame\n"
                "• The image is clear and well-lit\n"
                "• The leaf has visible symptoms or signs\n\n"
                "This app analyzes individual rice leaf diseases. "
                "Please upload a cleaner photo with only rice leaves.",
                []
            )

    # Fallback: No valid output from model
    return (
        "invalid_image",
        0.0,
        "Could not analyze image. Please ensure:\n"
        "• The image shows rice leaves ONLY\n"
        "• No people or objects are visible\n"
        "• The image is clear and well-lit\n"
        "• Focus on leaves with visible symptoms\n\n"
        "If the problem persists, try another image.",
        []
    )



@router.post("/predictions", response_model=PredictionOut)
async def create_prediction(
    request: Request,
    image: UploadFile = File(...),
    confidence_threshold: Optional[float] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):

    ext = os.path.splitext(image.filename or "")[1].lower()

    is_image_ct = bool(image.content_type) and image.content_type.startswith("image/")
    is_image_ext = ext in ALLOWED_EXT

    # DEBUG (temporary)
    print("UPLOAD DEBUG:",
        "filename=", image.filename,
        "content_type=", image.content_type,
        "ext=", ext,
        "confidence_threshold=", confidence_threshold)

    if not (is_image_ct or is_image_ext):
        raise HTTPException(status_code=400, detail="File must be an image")

    filename = f"{uuid4().hex}{ext}"
    file_path = os.path.join(UPLOAD_DIR, filename)

    # save file
    with open(file_path, "wb") as f:
        f.write(await image.read())

    # Ensure file is actually written (helps debug Windows path / permission issues)
    try:
        if (not os.path.exists(file_path)) or os.path.getsize(file_path) <= 0:
            raise RuntimeError(f"Upload save failed (missing/empty file): {file_path}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save upload: {e}")

    # Convert HEIC to JPEG if needed
    if ext == ".heic":
        try:
            file_path = _convert_heic_to_jpeg(file_path)
            filename = os.path.basename(file_path)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Could not process HEIC file: {str(e)}")

    # Parse confidence threshold if provided
    threshold_value = None
    if confidence_threshold is not None:
        try:
            threshold_value = float(confidence_threshold) if isinstance(confidence_threshold, str) else confidence_threshold
            print(f"AI DEBUG: Using custom confidence threshold: {threshold_value}")
        except (ValueError, TypeError):
            print(f"AI DEBUG: Invalid confidence_threshold value: {confidence_threshold}")
            threshold_value = None

    # AI output (real model if configured)
    try:
        label, confidence, advice, detections = ai_predict(file_path, threshold_value)
    except Exception as e:
        # Keep API usable during setup; return a clear message in advice.
        label = "brown_spot"
        confidence = 0.0
        advice = (
            "AI model is not available yet.\n\n"
            f"Reason: {e}\n\n"
            "Tip: Place your model at backend/models/rice_disease.pt "
            "or set AI_MODEL_PATH env var, then install ultralytics in the backend venv."
        )
        detections = []

    # Store relative path so mobile clients can prepend their own API base URL.
    image_url = f"/uploads/{filename}"

    pred = Prediction(
        user_id=current_user.id,
        image_filename=filename,
        image_url=image_url,
        label=label,
        confidence=confidence,
        advice=advice,
        detections=json.dumps(detections),  # Store detections as JSON
    )
    db.add(pred)
    db.commit()
    db.refresh(pred)
    
    # Update disease ranking statistics
    update_disease_ranking(db, label, user_location=current_user.location)
    
    log_activity(
        db,
        user_id=current_user.id,
        action="prediction.create",
        detail={"label": label, "confidence": confidence, "image_filename": filename},
        location=current_user.location
    )
    
    # Parse detections back to list for response
    detection_list = json.loads(pred.detections) if pred.detections else []
    
    # Return response with detections
    return PredictionOut(
        id=pred.id,
        label=pred.label,
        confidence=pred.confidence,
        advice=pred.advice,
        image_url=pred.image_url,
        created_at=pred.created_at,
        detections=detection_list,
    )

@router.get("/predictions", response_model=list[PredictionOut])
def list_predictions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    preds = (
        db.query(Prediction)
        .filter(Prediction.user_id == current_user.id)
        .order_by(Prediction.created_at.desc())
        .all()
    )
    # Parse detections JSON strings back to lists for Pydantic validation
    result = []
    for pred in preds:
        detection_list = json.loads(pred.detections) if pred.detections else []
        result.append(PredictionOut(
            id=pred.id,
            label=pred.label,
            confidence=pred.confidence,
            advice=pred.advice,
            image_url=pred.image_url,
            created_at=pred.created_at,
            detections=detection_list,
        ))
    return result

@router.get("/predictions/{prediction_id}", response_model=PredictionOut)
def get_prediction(
    prediction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    pred = (
        db.query(Prediction)
        .filter(Prediction.id == prediction_id, Prediction.user_id == current_user.id)
        .first()
    )
    if not pred:
        raise HTTPException(status_code=404, detail="Prediction not found")
    # Parse detections JSON string back to list for Pydantic validation
    detection_list = json.loads(pred.detections) if pred.detections else []
    return PredictionOut(
        id=pred.id,
        label=pred.label,
        confidence=pred.confidence,
        advice=pred.advice,
        image_url=pred.image_url,
        created_at=pred.created_at,
        detections=detection_list,
    )

@router.delete("/predictions/{prediction_id}")
def delete_prediction(
    prediction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    pred = (
        db.query(Prediction)
        .filter(Prediction.id == prediction_id, Prediction.user_id == current_user.id)
        .first()
    )
    if not pred:
        raise HTTPException(status_code=404, detail="Prediction not found")

    # delete file (optional)
    file_path = os.path.join(UPLOAD_DIR, pred.image_filename)
    if os.path.exists(file_path):
        try:
            os.remove(file_path)
        except Exception:
            pass

    db.delete(pred)
    db.commit()
    log_activity(
        db,
        user_id=current_user.id,
        action="prediction.delete",
        detail={"prediction_id": prediction_id, "image_filename": pred.image_filename},
    )
    return {"message": "Deleted"}

# ---- Chatbot Knowledge Base ----

DISEASE_KB = {
    "bacterial_blight": {
        "display": "Bacterial Blight (Rice Leaf Blight Disease)",
        "causal_agent": "Xanthomonas oryzae pv. oryzae",
        "severity": "High",
        "urgency": "Act quickly to prevent spread and yield loss",
        "explanation": (
            "Bacterial blight is one of the most serious rice diseases. It is caused by the bacterium "
            "Xanthomonas oryzae pv. oryzae. The disease usually starts at the leaf tip or leaf edge and "
            "can spread rapidly during rainy, windy, and wet conditions. Early infection can result in "
            "yield loss as high as 70% in susceptible varieties."
        ),
        "symptoms": [
            "Yellowing and wilting from the leaf tip or leaf margin",
            "Grayish-green leaves that roll up on seedlings (kresek stage)",
            "Water-soaked streaks with wavy margins on leaf blades",
            "Straw-colored lesions becoming yellow to grayish white",
            "Bacterial ooze resembling milky dew drops on young lesions",
            "Black dots from saprophytic fungi growth on old lesions",
            "Leaves dry out and wilt in severe infection",
            "Seedlings may suddenly wilt and die in severe cases"
        ],
        "causes": [
            "Bacteria (Xanthomonas oryzae pv. oryzae)",
            "Bacteria entering through wounds or stomata",
            "Heavy rain and strong wind spreading bacteria",
            "Contaminated irrigation water carrying bacteria",
            "Use of infected seeds or seedlings",
            "High humidity with relative humidity above 70%",
            "Temperature range of 25-34°C favoring disease development",
            "Excess nitrogen fertilizer increasing disease severity"
        ],
        "prevention": [
            "Use resistant rice varieties if available",
            "Plant disease-free and certified seeds",
            "Maintain good drainage in the field",
            "Avoid excessive nitrogen fertilizer - use balanced NPK",
            "Practice field sanitation and remove infected residues",
            "Control weeds and stubbles of infected plants",
            "Allow fallow fields to dry to suppress disease agents",
            "Avoid over-irrigation which promotes disease spread"
        ],
        "treatment_plan": [
            "Remove heavily infected plants if practical to reduce disease source",
            "Limit movement of contaminated water from infected areas",
            "Improve field drainage and reduce standing water",
            "Use copper-based bactericides only when locally recommended",
            "Apply approved bactericides only with local agricultural office guidance",
            "Consult an agriculture technician for proper management",
            "Monitor affected areas daily for disease progression"
        ],
        "fertilizer_guidance": [
            "Avoid too much nitrogen fertilizer which increases disease severity",
            "Apply balanced NPK fertilizer to maintain plant strength",
            "Ensure enough potassium to strengthen plant resistance",
            "Use balanced amounts of all plant nutrients",
            "Follow local recommendations for fertilizer application timing"
        ],
        "next_steps": [
            "Observe if yellowing is spreading to more leaves daily",
            "Check nearby plants for early signs of infection",
            "Limit movement of contaminated water in the field",
            "Keep records of affected areas for monitoring and planning"
        ],
        "when_to_contact": [
            "If large patches of plants are affected",
            "If seedlings wilt suddenly after planting",
            "If symptoms spread quickly after rain or flooding",
            "If more than 10% of plants show severe infection"
        ],
    },

    "leaf_blast": {
        "display": "Leaf Blast (Rice Leaf Blast Disease)",
        "causal_agent": "Magnaporthe oryzae (fungus)",
        "severity": "High",
        "urgency": "Act early because blast can spread quickly",
        "explanation": (
            "Leaf blast is one of the most destructive rice diseases worldwide, caused by the fungus "
            "Magnaporthe oryzae. It forms distinctive spindle-shaped lesions on leaves and can lead to "
            "serious yield loss if not managed early. The disease can cause complete crop loss in severe cases, "
            "with up to 50% yield loss observed. Blast spreads rapidly in wet and humid conditions."
        ),
        "symptoms": [
            "Spindle-shaped or diamond-shaped lesions on leaves",
            "Gray or whitish center with dark brown margins",
            "Small white/gray-green spots with dark borders initially",
            "Lesions enlarge and merge causing large dead areas",
            "Severely infected leaves may dry prematurely",
            "Leaf tips and leaf bases can be affected",
            "In seedlings: infected leaves turn grayish-green and roll up",
            "On mature plants: collar blast causes leaf death and plant weakness",
            "Nodal rot and black discoloration on stems and nodes"
        ],
        "causes": [
            "Fungal pathogen (Magnaporthe oryzae) producing airborne spores",
            "High humidity and frequent rainfall (above 70% humidity)",
            "Dense planting with poor airflow",
            "Excessive nitrogen application",
            "Temperature range of 24-28°C (optimal conditions)",
            "Long leaf wetness periods of 8+ hours",
            "Dew formation and dark/cloudy conditions favorable for spore release",
            "Infected crop residues and straw as inoculum source"
        ],
        "prevention": [
            "Use resistant varieties when available - most effective method",
            "Avoid excessive nitrogen fertilizer - use split applications",
            "Maintain proper plant spacing for good airflow",
            "Monitor fields closely during wet and humid periods",
            "Remove infected crop residues after harvest",
            "Apply silicon fertilizers in deficient soils to strengthen plants",
            "Avoid dense planting and ensure good field ventilation",
            "Early sowing after rains can reduce disease pressure"
        ],
        "treatment_plan": [
            "Remove severely infected leaves when practical",
            "Apply approved fungicides early if disease is spreading rapidly",
            "Use systemic fungicides such as triazoles or strobilurins",
            "Apply fungicide especially at heading stage for panicle blast prevention",
            "Improve field airflow by removing obstacles",
            "Reduce prolonged leaf wetness by removing irrigation covers",
            "Follow local agricultural recommendations for fungicide timing",
            "Apply fungicides as soon as lesions appear on leaves"
        ],
        "fertilizer_guidance": [
            "Avoid nitrogen spikes from over-fertilization",
            "Use split fertilizer application throughout growing season",
            "Maintain balanced NPK ratio with adequate potassium",
            "Silicon application strengthens plant resistance",
            "Avoid nitrogen at high concentrations during vulnerable growth stages",
            "Ensure adequate potassium for plant vigor"
        ],
        "next_steps": [
            "Inspect more leaves daily for spindle-shaped lesions",
            "Track whether lesions are increasing after rain events",
            "Act before disease reaches severe stage to prevent yield loss",
            "Scout fields regularly especially during wet season",
            "Keep records of lesion density to track progression"
        ],
        "when_to_contact": [
            "If lesions are rapidly increasing across multiple leaves",
            "If many leaves in one area are infected",
            "If fungicide guidance is needed for application timing",
            "If infection reaches heading stage (panicle blast risk)",
            "If more than 5% of leaves show blast symptoms"
        ],
    },

    "brown_spot": {
        "display": "Brown Spot (Rice Leaf Brown-Spot Disease)",
        "causal_agent": "Bipolaris oryzae (fungus)",
        "severity": "Moderate",
        "urgency": "Monitor closely and manage early if spreading",
        "explanation": (
            "Brown spot is a fungal disease that produces brown lesions on rice leaves, causing both "
            "yield and quality loss. It often becomes worse when rice plants are weak, nutrient-deficient, "
            "or under drought stress. The disease is historically linked to the Great Bengal Famine of 1943, "
            "which killed about 2 million people. Modern brown spot is usually minor but can cause 45% yield loss "
            "in severe cases, especially when plants are nutrient-deficient."
        ),
        "symptoms": [
            "Small brown oval or circular spots on leaves (like sesame seeds)",
            "Gray or whitish centers with yellow halos around lesions",
            "Early lesions appear as small dark brown spots on seedlings",
            "Mature lesions show reddish-brown borders and gray centers",
            "Spots may enlarge and merge when severe",
            "Leaves may become yellow and dry in advanced infection",
            "Severe infection causes leaves to split and die",
            "Brown-black spots can appear on leaf sheaths, panicles and grains",
            "Infected grains become discolored and poorly filled (pecky rice)",
            "Leaf surface breaks and releases black spores when wet"
        ],
        "causes": [
            "Fungal pathogen (Bipolaris oryzae also called Cochliobolus miyabeanus)",
            "Low soil fertility - especially potassium deficiency",
            "Nitrogen deficiency increasing susceptibility",
            "Drought stress or poor irrigation management",
            "Humid conditions and wet leaf surfaces",
            "Poor farming practices with inadequate fertilization",
            "Infected seeds and plant debris",
            "Temperature range of 16-36°C supporting infection",
            "Long leaf wetness periods of 8-24 hours"
        ],
        "prevention": [
            "Use healthy and certified seeds",
            "Apply balanced fertilizer including potassium",
            "Maintain proper irrigation to avoid drought stress",
            "Remove infected plant debris after harvest",
            "Avoid plant stress as much as possible",
            "Practice field sanitation and crop rotation",
            "Use clean seeds and remove weeds",
            "Apply calcium silicate or silicon amendments",
            "Ensure adequate potassium in soil"
        ],
        "treatment_plan": [
            "Remove heavily infected leaves if practical",
            "Improve field drainage and air movement",
            "Apply approved fungicide if disease progresses",
            "Treat seeds with fungicides before planting",
            "Use hot water seed treatment at 53-54°C for 10-12 minutes",
            "Consult local agriculture experts for severe infection",
            "Monitor frequently for disease progression"
        ],
        "fertilizer_guidance": [
            "Avoid excessive nitrogen which can worsen disease",
            "Ensure adequate potassium supply - critical for disease resistance",
            "Use balanced NPK fertilization (balanced nutrients reduce disease)",
            "Apply calcium silicate to strengthen plant tissues",
            "Avoid nutrient deficiency stress in fields",
            "Use slow-release fertilizers for consistent nutrition"
        ],
        "next_steps": [
            "Monitor whether spots are increasing on leaves",
            "Check if nutrient deficiency symptoms are also present",
            "Compare severity in different parts of field",
            "Test soil for potassium and nutrient levels",
            "Scout regularly during humid weather"
        ],
        "when_to_contact": [
            "If infection spreads rapidly to many plants",
            "If many leaves are affected and showing severe lesions",
            "If yield appears likely to be significantly reduced",
            "If fungicide treatment guidance is needed",
            "If seedlings show high mortality from brown spot infection"
        ],
    },

    "tungro": {
        "display": "Tungro (Rice Tungro Disease)",
        "causal_agent": "Rice Tungro Virus (RTBV + RTSV) - transmitted by green leafhoppers",
        "severity": "High",
        "urgency": "Immediate action is recommended - extremely destructive",
        "explanation": (
            "Tungro is a serious viral rice disease transmitted by green leafhoppers, occurring widely in "
            "South and Southeast Asia. It was first identified in 1965 at IRRI (Philippines). The disease "
            "can cause 100% yield loss in severe early infections. Transmission is very fast (within 5-7 days). "
            "It causes severe stunting, yellow-orange discoloration, and major yield loss due to sterilization "
            "of grains or poor grain filling."
        ),
        "symptoms": [
            "Yellow to orange leaf discoloration starting from leaf tips",
            "Stunted plant growth - plants much smaller than normal",
            "Reduced tillering - fewer shoots per plant",
            "Mottling, chlorosis, or striping on leaves",
            "Delayed flowering and maturity",
            "Poor or sterile grain filling",
            "Small, unfilled or completely discolored grains",
            "In Indica varieties: orange discoloration",
            "In Japonica varieties: yellowish discoloration",
            "Disease severity depends on plant age at infection (younger = worse)"
        ],
        "causes": [
            "Rice tungro virus complex (RTBV + RTSV)",
            "Transmission by green leafhopper (Nephotettix virescens) insects",
            "RTBV causes disease symptoms, RTSV acts as helper virus",
            "Nearby infected rice plants serving as inoculum source",
            "Infected stubbles and volunteer rice plants",
            "Continuous rice cropping without break",
            "High leafhopper population in area",
            "Movement of infected plants or leafhoppers between fields"
        ],
        "prevention": [
            "Use tungro-resistant varieties if available",
            "Control green leafhopper populations",
            "Remove infected plants early and completely",
            "Synchronize planting with nearby farms when possible",
            "Maintain good field sanitation - remove weeds",
            "Destroy infected stubbles after harvest",
            "Control volunteer rice and weed hosts",
            "Reduce leafhopper breeding sites",
            "Use clean nursery soil for raising seedlings",
            "Avoid late planting which attracts leafhoppers"
        ],
        "treatment_plan": [
            "Remove infected plants immediately to reduce virus source",
            "Control vector insects using approved insecticides",
            "Monitor surrounding plants for early infection signs",
            "Survey fields at least twice weekly during growing season",
            "Seek local pest management advice if outbreak is serious",
            "No cure once plant is infected - prevention is key",
            "Insecticides alone are not effective due to rapid leafhopper movement"
        ],
        "fertilizer_guidance": [
            "Avoid excessive nitrogen that may worsen pest pressure",
            "Use balanced fertilizer to maintain plant health",
            "Apply nutrients adequately to strengthen plant vigor",
            "Do not over-apply nitrogen which increases leafhopper attraction",
            "Ensure adequate potassium for plant strength"
        ],
        "next_steps": [
            "Check for green leafhoppers in the field daily",
            "Observe whether nearby plants show yellow-orange symptoms",
            "Act quickly to reduce spread to unaffected areas",
            "Isolate infected plants from healthy ones if possible",
            "Monitor young plants closely - they're most vulnerable"
        ],
        "when_to_contact": [
            "If many plants show tungro symptoms within 5-7 days",
            "If green leafhopper population is high and increasing",
            "If infection appears across large field areas",
            "If infection is detected in nursery seedlings",
            "If more than 10% of plants show symptoms"
        ],
    },

    "sheath_blight": {
        "display": "Sheath Blight",
        "causal_agent": "Rhizoctonia solani (fungus)",
        "severity": "High",
        "urgency": "Act quickly - can cause up to 50% yield loss",
        "explanation": (
            "Sheath blight is a major fungal rice disease caused by Rhizoctonia solani. It can cause yield loss "
            "up to 50% and affects rice production in India and other countries across Asia and the southern US. "
            "The disease primarily affects the leaf sheaths and leaves of rice plants. Unlike rice blast, resistant "
            "cultivars have not been found, making integrated management essential. Chemical control is currently "
            "the most effective option for managing this disease."
        ),
        "symptoms": [
            "Circular or oblong lesions on lower leaves, usually green-gray and water-soaked",
            "Lesions appear in late tillering or early internode elongation stage",
            "Lesions spread and reach upper parts of plant under high humidity",
            "When drier: lesions turn tan with brown borders",
            "Leaf dieback and sun penetration allows lesions to dry",
            "Sclerotia production near infection site (about 6 days)",
            "Black sclerotia fall off and survive in soil",
            "Infection spreads through field via irrigation water",
            "In severe cases: widespread leaf death and plant weakness",
            "Disease progresses better at high humidity and low sunlight"
        ],
        "causes": [
            "Fungal infection (Rhizoctonia solani)",
            "Sclerotia and mycelia overwinter in plant debris",
            "Spread via irrigation water during field preparation and flooding",
            "High humidity (above 70%) and low light favoring disease",
            "Temperature range of 25-30°C optimal for disease development",
            "Moisture from irrigation and rain promoting infection",
            "Closely planted fields increasing disease pressure",
            "Susceptibility increases with nitrogen fertilizer overuse"
        ],
        "prevention": [
            "Use systemic and non-systemic fungicides for control",
            "Maintain proper field drainage",
            "Avoid excessive nitrogen fertilizer application",
            "Use balanced NPK fertilization",
            "Remove or plow under infected plant debris after harvest",
            "Improve airflow and field conditions",
            "Practice good field sanitation",
            "Space plants appropriately to reduce humidity"
        ],
        "treatment_plan": [
            "Early detection is critical for control",
            "Apply systemic fungicides when disease is first detected",
            "Use approved chemical controls like azoxystrobin (QOI)",
            "Repeat fungicide applications as recommended",
            "Consult local agriculture experts for severe infection",
            "Chemical control is currently the most effective option",
            "Combine with cultural practices for best results"
        ],
        "fertilizer_guidance": [
            "Use balanced NPK fertilization",
            "Avoid excessive nitrogen application",
            "Maintain adequate but not excessive fertility",
            "Apply nutrients appropriately to avoid stress",
            "Ensure balanced soil nutrition for plant strength"
        ],
        "next_steps": [
            "Observe if dark growth is increasing on leaves",
            "Inspect nearby plants for similar symptoms",
            "Record affected field areas for monitoring",
            "Track disease progression over time",
            "Monitor during warm, humid weather"
        ],
        "when_to_contact": [
            "If infection spreads to many plants",
            "If black growth increases rapidly across field",
            "If yield loss is becoming likely",
            "If severe defoliation is occurring",
            "If damage exceeds acceptable economic threshold"
        ],
    },

    "sheath_blight": {
        "display": "Sheath Blight (Rice Sheath Blight Disease)",
        "causal_agent": "Soil-borne fungus and infected plant debris",
        "severity": "Moderate to High",
        "urgency": "Monitor closely and manage early to prevent spread",
        "explanation": (
            "Sheath blight is caused by a soil-borne fungus and spreads through contact with infected plants and water. "
            "In early stages, greenish-gray lesions appear on leaf sheaths. As the disease progresses, lesions enlarge and turn brown with gray centers and dark borders. "
            "In severe cases, the disease spreads to leaves causing yellowing and plant rot. Early detection and good field management are essential for control."
        ),
        "symptoms": [
            "Greenish-gray lesions on leaf sheaths in early stage",
            "Lesions enlarge and turn brown with gray centers in mid-stage",
            "Dark borders around lesions in advanced stage",
            "Spread to leaves causing yellowing in severe stage",
            "Plant rot and decay in heavily infected plants",
            "Lesions may spread up the plant affecting multiple plants",
            "Affected areas show progressive tissue death",
            "Water-soaked appearance initially on sheaths",
        ],
        "causes": [
            "Soil-borne fungus surviving in field",
            "Infected plant debris from previous crops",
            "Spread through plant-to-plant contact",
            "Water transmission between plants",
            "High humidity and warm temperatures favoring spread",
            "Poor field sanitation practices",
            "Contaminated farm equipment and tools"
        ],
        "prevention": [
            "Use resistant rice varieties when available",
            "Avoid close or crowded planting",
            "Maintain proper plant spacing for airflow",
            "Avoid excessive nitrogen fertilizer application",
            "Keep field clean after harvest",
            "Remove and destroy infected plant debris completely",
            "Practice crop rotation",
            "Control water flow and drainage in field"
        ],
        "treatment_plan": [
            "Scout fields regularly for early lesions",
            "Remove heavily infected plants if practical",
            "Reduce excessive nitrogen application",
            "Apply fungicides if disease is spreading rapidly",
            "Improve field drainage to reduce moisture",
            "Avoid contact between infected and healthy plants",
            "Follow local agricultural office recommendations"
        ],
        "fertilizer_guidance": [
            "Avoid excessive nitrogen which increases disease risk",
            "Use balanced fertilizer application",
            "Apply nutrients at appropriate timing",
            "Avoid stress from nutrient deficiency",
            "Use split applications rather than single heavy application"
        ],
        "next_steps": [
            "Inspect leaf sheaths regularly during growing season",
            "Monitor for spread to adjacent plants",
            "Check moisture levels and drainage in field",
            "Record affected areas for tracking",
            "Observe progression of lesion size"
        ],
        "when_to_contact": [
            "If lesions appear and are spreading to other plants",
            "If infection is moving rapidly through field",
            "If many plants are showing sheath blight symptoms",
            "If disease reaches heading stage",
            "If fungicide guidance is needed"
        ],
    },
}

def _normalize_language(language: str | None) -> str:
    v = (language or "english").strip().lower()
    if v in {"cebuano", "ceb", "bisaya"}:
        return "cebuano"
    return "english"


def _translate_text(text: str, language: str) -> str:
    if language != "cebuano":
        return text

    translations = {
        "Disease": "Sakit",
        "Severity": "Tubo sa kalason",
        "Urgency": "Kinahanglan ug bili",
        "Unknown": "Wala mailhi",
        "Symptoms": "Mga timailhan",
        "Causes": "Mga sanhi",
        "Prevention": "Pagbiwas",
        "Disease Management Strategy": "Plano sa pagluyeng sakit",
        "Fertilizer guidance": "Pagtoon sa pataba",
        "N/A": "Wala pa datos",
        "You can ask me about:": "Pwede ka pangutana bahin sa:",
        "symptoms": "mga timailhan",
        "causes": "mga sanhi",
        "prevention": "pagbiwas",
        "treatment": "pagluyeng",
        "fertilizer": "pataba",
        'Example: "symptoms" or "treatment and fertilizer"':
            'Sayup: "mga timailhan" o "pagluyeng ug pataba"',
        "Step ": "Hakbang ",
        "Note:": "Pasa-ingat:",
        "This is general guidance—follow local agriculture office recommendations for chemicals and approved products.":
            "Kini ay pangumum-ingon lang. Sunda ang mga rekomendasyon sa lokal na opisina sa agrikultura para sa mga kemikal ug aprubadong produkto.",
        "Note: This is general guidance—follow local agriculture office recommendations for chemicals and approved products.":
            "Pasa-ingat: Kini ay pangumum-ingon lang. Sunda ang mga rekomendasyon sa lokal na opisina sa agrikultura para sa mga kemikal ug aprubadong produkto.",
        "Use resistant rice varieties when available": "Gamita ang matibuk na barayti sa humay kung maa",
        "Avoid close or crowded planting": "Likayi ang siksad-sikad na pagtanum",
        "Maintain proper plant spacing for good airflow": "Panatili ang hustong layog sa tanom para sa maayong hangin",
        "Avoid excessive nitrogen fertilizer - use balanced NPK": "Likayi ang sobrang nitroheno - gamita ang balanseng NPK",
        "Practice field sanitation and remove infected residues": "Buhat ang likas-linisan sa uma ug alisin ang mga sakit na leavins",
        "Control weeds and stubbles of infected plants": "Kontrola ang mga sagbot ug mga likod sa sakit na tanom",
        "Allow fallow fields to dry to suppress disease agents": "Ulian ang walang paleng uma aron mapugnan ang sakit",
        "Avoid over-irrigation which promotes disease spread": "Likayi ang sobrang tubig na nagpalakas sa sakit",
        "Keep field clean after harvest": "Panatili ang malinis na uma human sa ani",
        "Remove and destroy infected plant debris completely": "Alisin ug sirain ang lahat ng sakit na leavins",
        "Practice crop rotation": "Buhat ang pag-rotate ng tanim",
        "Control water flow and drainage in field": "Kontrolin ang daloy ng tubig at pag-drenahe sa bukid",
        "Remove infected crop residues after harvest": "Alisin ang nakahawang residue ng tanim pagkatapos ng ani",
        "Use silicon fertilizers in deficient soils to strengthen plants": "Gumamit ng silicon fertilizer sa kulang na lupa upang mapalaki ang tanim",
        "Monitor fields closely during wet and humid periods": "Bantayan ang bukid nang mabuti sa panahon ng basa at mainit",
        "Apply silicon fertilizers in deficient soils to strengthen plants": "Magbigay ng silicon fertilizer sa kulang na lupa upang magpalakas ng tanim",
        "Early sowing after rains can reduce disease pressure": "Ang maagagang pagtanim pagkatapos ng ulan ay maaaring mabawasan ang presyon ng sakit",
        "Plant disease-free and certified seeds": "Magtanim ng walang sakit at certified na binhi",
        "Plant disease-free seeds": "Magtanim ng walang sakit na binhi",
        "Maintain good drainage in the field": "Panatilihin ang magandang pag-drenahe sa bukid",
        "Avoid excessive nitrogen fertilizer": "Iwasan ang sobra na nitrogen fertilizer",
        "Ensure adequate potassium to strengthen plant resistance": "Siguruhing may sapat na potassium upang palakasin ang resistance ng tanim",
        "Use balanced amounts of all plant nutrients": "Gumamit ng balanseng halaga ng lahat ng nutrients ng tanim",
        "Follow local recommendations for fertilizer application timing": "Sundin ang lokal na rekomendasyon para sa tamang oras ng pagbibigay ng pataba",
        "Limit movement of contaminated water from infected areas": "Limitahan ang paggalaw ng napollutong tubig mula sa napektadong lugar",
        "Improve field drainage and reduce standing water": "Mapabuti ang pag-drenahe ng bukid at bawasan ang nakatigil na tubig",
        "Use copper-based bactericides only when locally recommended": "Gumamit ng copper-based na bactericide lamang kung inirekomenda ng lokal",
        "Apply approved bactericides only with local agricultural office guidance": "Magbigay ng aprubadong bactericide lamang gamit ang gabay ng lokal na opisina ng pagsasaka",
        "Consult an agriculture technician for proper management": "Magtanong sa tecnisyan ng impormasyon tungkol sa husay na pamamahala",
        "Remove heavily infected plants if practical to reduce disease source": "Alisin ang lubhang nakahawang tanim kung praktikal upang mabawasan ang source ng sakit",
        "Apply fungicides early if disease is spreading rapidly": "Magbigay ng fungicide nang maaga kung ang sakit ay mabilis kumakalat",
        "Use systemic fungicides such as triazoles or strobilurins": "Gumamit ng systemic fungicides tulad ng triazoles o strobilurins",
        "Apply fungicide especially at heading stage for panicle blast prevention": "Magbigay ng fungicide lalo na sa heading stage para sa prevention ng panicle blast",
        "Improve field airflow by removing obstacles": "Mapabuti ang airflow sa bukid sa pamamagitan ng pag-alis ng hadlang",
        "Reduce prolonged leaf wetness by removing irrigation covers": "Bawasan ang mahabang pagkabasa ng dahon sa pamamagitan ng pag-alis ng irrigation covers",
        "Follow local agricultural recommendations for fungicide timing": "Sundin ang lokal na rekomendadong panahon ng pagbibigay ng fungicide",
        "Apply fungicides as soon as lesions appear on leaves": "Magbigay ng fungicide sa lalong madaling panahon kapag lumilitaw ang samad sa dahon",
        "Avoid nitrogen spikes from over-fertilization": "Iwasan ang bigla-biglang pagtaas ng nitrogen mula sa sobrang pataba",
        "Use split fertilizer application throughout growing season": "Gumamit ng hinay-hinay na pagbibigay ng pataba sa buong panahon ng paglaki",
        "Maintain balanced NPK ratio with adequate potassium": "Manatili sa balanse ng NPK ratio na may sapat na potassium",
        "Silicon application strengthens plant resistance": "Ang paggamit ng silicon ay nagpapalakas ng resistance ng tanim",
        "Avoid nitrogen at high concentrations during vulnerable growth stages": "Iwasan ang mataas na konsentrasyon ng nitrogen sa madaling ma-apekto na yugto ng paglaki",
        "Ensure adequate potassium for plant vigor": "Siguruhing may sapat na potassium para sa lakas ng tanim",
        "Inspect more leaves daily for spindle-shaped lesions": "Suriin ang maraming dahon araw-araw para sa spindle-shaped na samad",
        "Track whether lesions are increasing after rain events": "Bantayan kung ang mga samad ay dumarami pagkatapos ng ulan",
        "Act before disease reaches severe stage to prevent yield loss": "Kumilos bago ang sakit ay maging sobrang lala upang maiwasan ang pagkawala ng ani",
        "Scout fields regularly especially during wet season": "Tuklasin ang mga bukid nang regular lalo na sa panahon ng ulan",
        "Keep records of lesion density to track progression": "Panatilihin ang rekord ng density ng samad upang subaybayan ang pag-unlad",
        "If large patches of plants are affected": "Kung ang malalaking bahagi ng mga tanim ay apektado",
        "If seedlings wilt suddenly after planting": "Kung ang mga bigas ay kalit na namumukod pagkatapos ng pagtanim",
        "If symptoms spread quickly after rain or flooding": "Kung ang mga sintoma ay nagsumusulpot nang mabilis pagkatapos ng ulan o baha",
        "If more than 10% of plants show severe infection": "Kung higit sa 10% ng mga tanim ay nagpapakita ng malalang nakakahawa",
        "If many leaves in one area are infected": "Kung maraming dahon sa isang lugar ay nakahawa",
        "If fungicide guidance is needed for application timing": "Kung kailangan ng gabay sa fungicide para sa tamang oras ng pagbibigay",
        "If infection reaches heading stage (panicle blast risk)": "Kung ang nakakahawa ay umaabot sa heading stage (pericle blast risk)",
        "If more than 5% of leaves show blast symptoms": "Kung higit sa 5% ng mga dahon ay nagpapakita ng blast symptoms",
        "If infection spreads rapidly to many plants": "Kung ang nakakahawa ay mabilis kumakalat sa maraming tanim",
        "If yield appears likely to be significantly reduced": "Kung ang ani ay lumilitaw na biglang babawasan",
        "If symptom spread quickly": "Kung ang sintoma ay mabilis kumakalat",
        "If seedlings show high mortality from brown spot infection": "Kung ang mga bigas ay nagpapakita ng mataas na pagkamatay mula sa brown spot infection",
        "Avoid excessive nitrogen fertilizer application": "Iwasan ang sobra na pagbibigay ng nitrogen fertilizer",
        "Practice crop rotation": "Magsagawa ng pag-rotate ng tanim",
        "Soil-borne fungus and infected plant debris": "Fungus na nagmumula sa lupa at nakahawang debris ng tanim",
        "Monitor closely and manage early to prevent spread": "Bantayin nang mabuti at pamahalaan nang maaga upang maiwasan ang pagkaylap",
        "Note: This is general guidanceâ€”follow local agriculture office recommendations for chemicals and approved products.":
            "Pahimangno: Kin general nga giya lamang kini. Sunda ang rekomendasyon sa lokal nga agriculture office bahin sa kemikal ug giaprobahang produkto.",
        "Please verify the image / label": "Palihog susiha pag-usab ang hulagway o label",
        "I don't recognize this disease label yet.": "Wala pa nako mailhi kining label sa sakit.",
        "Unknown disease label. Try re-scanning or consult your local agriculture officer.":
            "Wala mailhi ang label sa sakit. Sulayi og scan pag-usab o pakigkonsulta sa inyong lokal nga agriculture officer.",
        "Try a clearer photo in good lighting": "Sulayi og mas klaro nga hulagway nga hayag ang suga",
        "Capture both close-up and whole leaf": "Kuhaa ang hulagway sa duol ug sa tibuok dahon",
        "Avoid chemicals until confirmed": "Likayi sa ang kemikal hangtod makumpirma ang sakit",
        "Use balanced fertilization; avoid excessive nitrogen while unsure":
            "Gamita ang balanse nga abono ug likayi ang sobra nga nitrogen kon dili pa sigurado",
        "Re-scan with a clearer image": "Pag-scan pag-usab gamit ang mas klaro nga hulagway",
        "Consult an agriculture technician": "Pakigkonsulta sa agriculture technician",
        "If symptoms spread quickly": "Kung paspas mikatag ang mga sintomas",
        "If large patches show symptoms": "Kung daghang bahin sa uma ang adunay sintomas",
        "High": "Taas",
        "Moderate": "Katamtaman",
        "Act quickly to prevent spread and yield loss":
            "Kumilos dayon upang maiwasan ang kakalat ug pagkawala sa ani",
        "Act early because blast can spread quickly":
            "Kumilos nang maaga dahil ang blast ay mabilis kumakalat",
        "Monitor closely and manage early if spreading":
            "Bantayi nang mabuti at pamahalaan nang maaga kung kumakalat",
        "Immediate action is recommended": "Girekomendar ang dayon na aksyon",
        "Bacterial blight is a serious rice disease caused by bacteria. It usually starts at the leaf tip or leaf edge and can spread fast during rainy, windy, and wet conditions.":
            "Ang bacterial blight ay isang seryosong sakit sa humay na dulot ng mga bakteri. Karaniwang nagsisimula ito sa tuktok o gilid ng dahon at mabilis kumakalat sa ulan ug hangin.",
        "Yellowing from the leaf tip or leaf margin":
            "Pagkadilim gikan sa tuktok o gilid ng dahon",
        "Water-soaked streaks that later turn straw-colored":
            "Mga linya na parang basang-basa na unya nagiging kulay-uhot",
        "Leaves dry out and wilt in severe infection":
            "Mamala ug walayang ang mga dahon kung lubhang kalason",
        "Seedlings may suddenly wilt in severe cases":
            "Ang mga binhi ay maaaring kalit na walayang sa lubhang kaso",
        "Bacteria (Xanthomonas oryzae pv. oryzae)":
            "Bakteri (Xanthomonas oryzae pv. oryzae)",
        "Heavy rain and strong wind":
            "Kusog na ulan ug hangin",
        "Contaminated irrigation water":
            "Napulan na tubig sa irrigasyon",
        "Use of infected seeds or seedlings":
            "Paggamit og natakdan nga liso o semilya",
        "Use resistant rice varieties if available":
            "Gamita ang barayti sa humay nga mas resistant kung naa",
        "Plant disease-free seeds":
            "Pagtanom og liso nga walay sakit",
        "Maintain good drainage in the field":
            "Siguroa ang maayong drainage sa uma",
        "Avoid excessive nitrogen fertilizer":
            "Likayi ang sobra nga nitrogen nga abono",
        "Practice field sanitation and remove infected residues":
            "Buhata ang limpyo nga pagdumala sa uma ug kuhaa ang mga natakdan nga salin",
        "Remove heavily infected plants if practical":
            "Kuhaa ang grabeng natakdan nga tanom kung mahimo",
        "Reduce standing water movement from infected areas":
            "Paminusi ang paglihok sa nagbarog nga tubig gikan sa natakdan nga bahin",
        "Improve field drainage":
            "Paayoha ang drainage sa uma",
        "Use approved bactericides only when locally recommended":
            "Gamita lamang ang giaprobahang bactericide kung girekomendar sa inyong lugar",
        "Consult an agriculture technician for proper management":
            "Pakigkonsulta sa agriculture technician alang sa hustong pagdumala",
        "Avoid too much nitrogen fertilizer":
            "Likayi ang sobra kaayo nga nitrogen nga abono",
        "Apply balanced NPK fertilizer":
            "Pagbutang og balanse nga NPK nga abono",
        "Ensure enough potassium to strengthen plant resistance":
            "Siguroa nga igo ang potassium aron molig-on ang resistensya sa tanom",
        "Leaf blast is a fungal disease of rice caused by Magnaporthe oryzae. It forms distinctive lesions on leaves and can lead to serious yield loss if not managed early.":
            "Ang leaf blast ay isang fungal disease sa humay na dulot ng Magnaporthe oryzae. Nagbubuo ito ng malinaw na samad sa mga dahon at maaaring magresulta sa malaking pagkawala ng ani.",
        "Spindle-shaped lesions on leaves":
            "Mga samad na may hugisng spindle sa mga dahon",
        "Gray or whitish center with brown margins":
            "Grayish o maputing gitna na may brown na kilid",
        "Lesions enlarge and may merge":
            "Lumaki ang mga samad at maaaring pagsama",
        "Severely infected leaves may dry prematurely":
            "Ang lubhang sakit na mga dahon ay maaaring mamala nang maaga",
        "Fungal pathogen (Magnaporthe oryzae)":
            "Fungal pathogen (Magnaporthe oryzae)",
        "High humidity and frequent rainfall":
            "Taas nga humidity ug sige'g ulan",
        "Dense planting with poor airflow":
            "Siksik nga pagtanom nga kulang sa airflow",
        "Excessive nitrogen application":
            "Sobra nga paggamit og nitrogen",
        "Use resistant varieties when available":
            "Gamita ang resistant nga barayti kung naa",
        "Maintain proper plant spacing for airflow":
            "Sunda ang hustong gilay-on sa tanom aron naay airflow",
        "Monitor fields closely during wet and humid periods":
            "Bantayi pag-ayo ang uma panahon sa basa ug humid nga kondisyon",
        "Remove infected crop residues after harvest":
            "Kuhaa ang natakdan nga salin sa tanom human sa ani",
        "Remove severely infected leaves when possible":
            "Kuhaa ang grabeng natakdan nga dahon kung mahimo",
        "Apply approved fungicide early if disease is spreading":
            "Pagbutang og giaprobahang fungicide sayo pa kung mikaylap ang sakit",
        "Improve field airflow and reduce prolonged leaf wetness":
            "Paayoha ang airflow sa uma ug paminusi ang dugay nga pagkabasa sa dahon",
        "Follow local agricultural recommendations for fungicide timing":
            "Sunda ang lokal nga rekomendasyon sa tamang oras sa fungicide",
        "Avoid nitrogen spikes from over-fertilization":
            "Likayi ang kalit nga pagsaka sa nitrogen tungod sa sobrang abono",
        "Use split fertilizer application":
            "Gamita ang hinay-hinay nga paghatag sa abono",
        "Maintain balanced NPK and adequate potassium":
            "Padayon sa balanse nga NPK ug igo nga potassium",
        "Brown spot is a fungal disease that produces brown lesions on rice leaves. It often becomes worse when rice plants are weak, nutrient-deficient, or under drought stress.":
            "Ang brown spot ay isang fungal disease na nagbubuo ng brown na samad sa mga dahon ng humay. Lumalalala ito kapag ang humay ay mahuyang, kulang sa nutrisyon, o na-stress sa tuyot.",
        "Small circular to oval brown spots on leaves":
            "Gagmay na round o oval na brown na tuldok sa mga dahon",
        "Yellow halos around lesions":
            "Dilaw na mga halo sa paligid ng mga samad",
        "Spots may enlarge and merge when severe":
            "Ang mga tuldok ay maaaring lumaki ug pagsama kung lubhang kalason",
        "Leaves may dry or weaken in advanced infection":
            "Ang mga dahon ay maaaring mamala o maging mahina sa mas malalim na kalason",
        "Fungal pathogen (Bipolaris oryzae)":
            "Fungal pathogen (Bipolaris oryzae)",
        "Low soil fertility, especially potassium deficiency":
            "Mababang katambok ng lupa, lalo na kung kulang sa potassium",
        "Drought stress or poor irrigation":
            "Stress dahil sa tuyot o masamang irrigasyon",
        "Humid conditions and wet leaf surfaces":
            "Humid nga kahimtang ug basa nga ibabaw sa dahon",
        "Use healthy and certified seeds":
            "Gamita ang himsog ug certified nga liso",
        "Apply balanced fertilizer including potassium":
            "Pagbutang og balanse nga abono nga adunay potassium",
        "Maintain proper irrigation":
            "Siguroa ang hustong irigasyon",
        "Remove infected plant debris after harvest":
            "Kuhaa ang natakdan nga salin sa tanom human sa ani",
        "Avoid plant stress as much as possible":
            "Likayi kutob sa mahimo ang stress sa tanom",
        "Improve field drainage and air movement":
            "Paayoha ang drainage sa uma ug lihok sa hangin",
        "Apply approved fungicide if disease spreads":
            "Pagbutang og giaprobahang fungicide kung mikaylap ang sakit",
        "Consult local agriculture experts for severe infection":
            "Pakigkonsulta sa lokal nga eksperto sa agrikultura kung grabe ang impeksyon",
        "Ensure adequate potassium supply":
            "Siguroa ang igo nga suplay sa potassium",
        "Use balanced NPK fertilization":
            "Gamita ang balanse nga NPK nga abono",
        "Tungro is a viral rice disease transmitted by green leafhoppers. It can cause severe stunting, yellow-orange discoloration, and major yield loss.":
            "Ang tungro usa ka viral disease sa humay nga gidala sa green leafhoppers. Mahimo kini makapahinay sa pagtubo, mopadilaw o mopaka-orange sa dahon, ug makapawala og dako sa ani.",
        "Yellow to orange leaf discoloration":
            "Dilaw hangtod orange nga pag-usab sa kolor sa dahon",
        "Stunted plant growth":
            "Pahinay nga pagtubo sa tanom",
        "Reduced tillering":
            "Mikagamay ang pagdami sa sanga",
        "Delayed flowering and poor grain filling":
            "Nalangan ang pagpamulak ug dili maayong pagpuno sa lugas",
        "Rice tungro virus infection":
            "Impeksyon sa rice tungro virus",
        "Transmission by green leafhopper insects":
            "Pagbalhin pinaagi sa green leafhopper nga insekto",
        "Nearby infected rice plants serving as source":
            "Ang duol nga natakdan nga humay mahimong tinubdan sa sakit",
        "Use tungro-resistant varieties if available":
            "Gamita ang tungro-resistant nga barayti kung naa",
        "Control leafhopper populations":
            "Kontrola ang populasyon sa leafhopper",
        "Remove infected plants early":
            "Kuhaa dayon ang natakdan nga tanom",
        "Synchronize planting with nearby farms when possible":
            "Ipares ang iskedyul sa pagtanom sa duol nga uma kung mahimo",
        "Maintain good field sanitation":
            "Padayona ang maayong kahinlo sa uma",
        "Remove infected plants to reduce virus source":
            "Kuhaa ang natakdan nga tanom aron maminusan ang tinubdan sa virus",
        "Control vector insects using approved methods":
            "Kontrola ang mga insekto nga nagdala sa sakit gamit ang giaprobahang paagi",
        "Monitor surrounding plants for early infection":
            "Bantayi ang kasikbit nga tanom alang sa sayong impeksyon",
        "Seek local pest management advice if outbreak is serious":
            "Pangayo og lokal nga tambag sa pest management kung seryoso ang outbreak",
        "Avoid excessive nitrogen that may worsen pest pressure":
            "Likayi ang sobra nga nitrogen nga mahimong mopadaghan sa peste",
        "Use balanced fertilizer to maintain plant health":
            "Gamita ang balanse nga abono aron mapadayon ang kahimsog sa tanom",
        
        # Enhanced disease information translations
        "Bacterial Blight":
            "Bacterial Blight",
        "Leaf Blast":
            "Leaf Blast",
        "Brown Spot":
            "Brown Spot",
        "Tungro":
            "Tungro",
        "Sheath Blight":
            "Sheath Blight",
        "Xanthomonas oryzae pv. oryzae":
            "Xanthomonas oryzae pv. oryzae",
        "Magnaporthe oryzae (fungus)":
            "Magnaporthe oryzae (fungus)",
        "Bipolaris oryzae (fungus)":
            "Bipolaris oryzae (fungus)",
        "Rhizoctonia solani (fungus)":
            "Rhizoctonia solani (fungus)",
        "Rice Tungro Virus (RTBV + RTSV) - transmitted by green leafhoppers":
            "Rice Tungro Virus (RTBV + RTSV) - transmitted by green leafhoppers",
        
        # Bacterial Blight additional translations
        "Grayish-green leaves that roll up on seedlings (kresek stage)":
            "Abumadong-dilaw na mga dahon na tumiligid sa mga bigas (kresek stage)",
        "Water-soaked streaks with wavy margins on leaf blades":
            "Mga guhit na parang basang-basa na may ulot na kilid sa dahon",
        "Straw-colored lesions becoming yellow to grayish white":
            "Mga samad na kulay uhot na nagiging dilaw o grayish white",
        "Bacterial ooze resembling milky dew drops on young lesions":
            "Bacterial ooze na parang gatas na aining sa kabataan na mga samad",
        "Black dots from saprophytic fungi growth on old lesions":
            "Itim na ponto mula sa fungal na paglaki sa lumang mga samad",
        "Bacteria entering through wounds or stomata":
            "Mga bakterya na pumapasok sa pamamagitan ng sugat o stomata",
        "Temperature range of 25-34°C favoring disease development":
            "Temperatura mula 25-34°C na kinabibigyan ang sakit",
        "High humidity with relative humidity above 70%":
            "Taas na humidity na may humility sa itaas ng 70%",
        "Allow fallow fields to dry to suppress disease agents":
            "Hayaang matuyo ang bakanteng mga uma aron mapigilan ang sakit",
        
        # Leaf Blast additional translations
        "Leaf tips and leaf bases can be affected":
            "Ang mga tumoy at batayan ng dahon ay maaaring makasacrifice",
        "In seedlings: infected leaves turn grayish-green and roll up":
            "Sa mga bigas: ang natakdan na mga dahon ay nagiging grayish-green at tumitigid",
        "On mature plants: collar blast causes leaf death and plant weakness":
            "Sa mga tanom na laki: ang collar blast ay nakakaursang patay sa dahon at paghuyang tanom",
        "Nodal rot and black discoloration on stems and nodes":
            "Nodal rot at itim na kulay sa mga tangkay at node",
        "Dew formation and dark/cloudy conditions favorable for spore release":
            "Pagporma ng aning at madilim/ulap na kondisyon na angkop sa pagpalakas ng spore",
        "Infected crop residues and straw as inoculum source":
            "Natakdan na kasamadang tanim at uhot bilang tinubdan ng sakit",
        "Most destructive rice diseases worldwide":
            "Pinakarusak na sakit sa humay sa buong mundo",
        "Bloom-and-bust cycles with resistance breaking down":
            "Bloom-and-bust cycle na ang resistansya ay bumagsak",
        "Spores released mainly at night (2 AM – 6 AM)":
            "Mga spore na inilalabas sa gabi (2 AM – 6 AM)",
        "Sporulation (rapid spread stage)":
            "Pagporma ng spore (mabilis na kumakalat na stage)",
        
        # Brown Spot additional translations
        "Small brown oval or circular spots on leaves (like sesame seeds)":
            "Gagmay na brown na oval o lingin na mga tuldok sa dahon (parang lino)",
        "Gray or whitish centers with yellow halos around lesions":
            "Abu o maputing gitna na may dilaw na palibot sa mga samad",
        "Early lesions appear as small dark brown spots on seedlings":
            "Ang maaring mga samad ay lumilitaw bilang gagmay na madilim na brown na tuldok sa mga bigas",
        "Mature lesions show reddish-brown borders and gray centers":
            "Ang lumalaking mga samad ay nagpapakita ng reddish-brown na hangganan at gray na gitna",
        "Infected grains become discolored and poorly filled (pecky rice)":
            "Ang natakdan na lugas ay nagiging walang kulay at dili maayong napuno (pecky rice)",
        "Leaf surface breaks and releases black spores when wet":
            "Ang ibabaw ng dahon ay putok at naglalabas ng itim na spore kung basa",
        "Great Bengal Famine of 1943":
            "Great Bengal Famine ng 1943",
        "Can cause 45% yield loss in severe cases":
            "Maaaring maging sanhi ng 45% na pagkawala sa ani sa mga mahabang kaso",
        "Testing with hot water at 53-54°C for 10-12 minutes":
            "Pagsubok gamit ang mainit na tubig sa 53-54°C ng 10-12 minuto",
        "Sesame-like spots on leaves":
            "Mga tuldok na parang lino sa mga dahon",
        
        # Tungro additional translations
        "Viral disease transmitted by insects":
            "Viral disease na gidala ng mga insekto",
        "Can cause 100% yield loss in severe early infections":
            "Maaaring maging sanhi ng 100% na pagkawala sa ani sa mga mahabang early na impeksyon",
        "Transmission within 5-7 days":
            "Pagbalhin sa loob ng 5-7 na araw",
        "RTBV causes disease symptoms, RTSV acts as helper virus":
            "Ang RTBV ay nagdudulot ng mga sintoma, ang RTSV ay gumagana bilang tulong na virus",
        "Green leafhopper (Nephotettix virescens) insects":
            "Green leafhopper (Nephotettix virescens) na mga insekto",
        "Continuous rice cropping without break":
            "Patuloy na pagtanim ng humay nang walang tigil",
        "First identified in 1965 at IRRI (Philippines)":
            "Una naming kinikilala noong 1965 sa IRRI (Philippines)",
        "High leafhopper population in area":
            "Mataas na populasyon ng leafhopper sa lugar",
        "Isolated infected plants from healthy ones":
            "Ihiwalay ang natakdan na tanom mula sa mga himsog",
        "Young plants are most vulnerable and attractive to leafhoppers":
            "Ang mga kabataan na tanom ay pinakamahinang at kaakit-akit sa mga leafhopper",
        "Green leafhoppers in the field daily":
            "Mga green leafhopper sa uma araw-araw",
        "Destroy infected stubbles after harvest":
            "Sirain ang natakdan na mga usbong human sa ani",
        
        # Leaf Smut additional translations
        "Pepper dust appearance on leaves":
            "Parang asuwan ang hitsura sa mga dahon",
        "Fungus/fungal infection":
            "Fungus/fungal na impeksyon",
        "Small, slightly raised black spots":
            "Gagmay, bahagyang nataas na itim na mga tuldok",
        "Short, rectangular or oval shaped spots":
            "Maikling, rektanggulo o oval na hugis na mga tuldok",
        "0.5-5 mm in length":
            "0.5-5 mm sa haba",
        "Many spots on one leaf but not merging together":
            "Maraming mga tuldok sa isang dahon ngunit hindi nagsasama",
        "Distinct and scattered spot distribution":
            "Malinaw at makalalat na distribusyon ng tuldok",
        "Appears on older leaves first":
            "Unang lumilitaw sa mga lumang dahon",
        "Black spores resembling soot or powder":
            "Itim na mga spore na parang aisbog o powder",
        "Low damage in most cases":
            "Mababang pinsala sa karamihan ng mga kaso",
        "Prevention and good farming are usually sufficient":
            "Ang paglikay at maayong pagsasaka ay karaniwang sapat",
        
        # Next steps and contact translations
        "Check for green leafhoppers in the field daily":
            "Tignan ang mga green leafhopper sa uma araw-araw",
        "Observe whether nearby plants show yellow-orange symptoms":
            "Bantayan kung ang mga kasikbit na tanom ay nagpapakita ng dilaw-orange na mga sintoma",
        "Scout for pest population regularly":
            "Siyensya ang populasyon ng peste nang regular",
        "More than 10% of plants show severe infection":
            "Mahigit 10% ng mga tanom ay nagpapakita ng mabigat na impeksyon",
        "If seedlings show high mortality from brown spot":
            "Kung ang mga bigas ay nagpapakita ng mataas na kamatayan mula sa brown spot",
        "Acceptable economic threshold":
            "Katanggap-tanggap na economic threshold",
        
        # General agricultural guidance
        "Pest management advice":
            "Tambag sa pamamahala ng peste",
        "Local agricultural office recommendations":
            "Rekomendasyon ng lokal na agriculture office",
        "Copper-based bactericides":
            "Copper-based bactericides",
        "Systemic fungicides (triazoles, strobilurins)":
            "Systemic fungicides (triazoles, strobilurins)",
        "Reduced yield and quality":
            "Pababang ani at kalidad",
        "Field sanitation practices":
            "Practices sa kalingahan ng uma",
        "Crop rotation":
            "Pag-rotate ng tanim",
        "Soil fertility management":
            "Pamamahala sa katambok ng lupa",
        "Integrated Pest Management (IPM)":
            "Integrated Pest Management (IPM)",
        
        # Section headers with newline
        "\nSymptoms": "\nMga Sintomas",
        "\nCauses": "\nMga Hinungdan",
        "\nPrevention": "\nPaglikay",
        "\nDisease Management Strategy": "\nEstrateheya sa Pangangasiwa ng Sakit",
        "\nFertilizer guidance": "\nGiya sa Abono",
        "\nNext steps": "\nSunod na Hakbang",
        "\nWhen to contact": "\nKailan Makipag-ugnayan",
        
        # UI labels and text
        "Disease:": "Sakit:",
        "Severity:": "Kahusay:",
        "Urgency:": "Madali:",
        "Example:": "Halimbawa:",
        "N/A": "Walang Impormasyon",
        "-": "-",
        "You can ask me about:": "Maaari mong itanong sa akin tungkol sa:",
        "Note:": "Paalala:",
        "Observation:": "Obserbasyon:",
        "Ask me about:": "Itanong sa akin tungkol sa:",
        
        # Disease explanations (full translations)
        "Bacterial blight is one of the most serious rice diseases. It is caused by the bacterium Xanthomonas oryzae pv. oryzae. The disease usually starts at the leaf tip or leaf edge and can spread rapidly during rainy, windy, and wet conditions. Early infection can result in yield loss as high as 70% in susceptible varieties.":
            "Ang bacterial blight usa ka seryoso kaayong sakit sa humay. Tungod ito sa bakterya na Xanthomonas oryzae pv. oryzae. Kasagaran magsugod kini sa tumoy o kilid sa dahon at dali mokatag panahon sa ulan, kusog nga hangin, ug basa nga palibot. Pagkaabot sa maaga na impeksyon ay maaari magdulot ng hanggang 70% na pagkawala sa ani sa mga sensitibong barayti.",
        
        "Leaf blast is one of the most destructive rice diseases worldwide, caused by the fungus Magnaporthe oryzae. It forms distinctive spindle-shaped lesions on leaves and can lead to serious yield loss if not managed early. The disease can cause complete crop loss in severe cases, with up to 50% yield loss observed. Blast spreads rapidly in wet and humid conditions.":
            "Ang leaf blast isa sa pinakadistruktibong sakit sa humay sa buong mundo, tungod sa fungus na Magnaporthe oryzae. Ito ay bumubuo ng mga natatanging spindle-shaped na mga ulcer sa mga dahon at maaaring magdulot ng seryosong pagkawala sa ani kung hindi ito inayuhan nang maaga. Ang sakit ay maaaring magdulot ng kumpletong kaluwal sa ani sa mga grabe na kaso, na may hanggang 50% na pagkawala sa ani. Ang blast ay kumakalat nang mabilis sa basa at mainit na palibot.",
        
        "Brown spot is a fungal disease that produces brown lesions on rice leaves, causing both yield and quality loss. It often becomes worse when rice plants are weak, nutrient-deficient, or under drought stress. The disease is historically linked to the Great Bengal Famine of 1943, which killed about 2 million people. Modern brown spot is usually minor but can cause 45% yield loss in severe cases, especially when plants are nutrient-deficient.":
            "Ang brown spot usa ka fungal na sakit na gumagawa ng mga buwang ulcer sa mga dahon ng humay, na nagdudulot ng pagkawala sa ani at kalidad. Ito ay mas nagiging palit-palit kapag ang mga tanom ng humay ay mahina, kulang sa nutrients, o nasa under drought stress. Ang sakit ay nahistoryakong konektado sa Great Bengal Famine ng 1943, na nakamatay ng mga 2 milyong tao. Ang modernong brown spot ay karaniwang minor lamang ngunit maaaring magdulot ng 45% na pagkawala sa ani sa mga grabe na kaso, lalo na kapag ang mga tanom ay kulang sa nutrients.",
        
        "Tungro is a serious viral rice disease transmitted by green leafhoppers, occurring widely in South and Southeast Asia. It was first identified in 1965 at IRRI (Philippines). The disease can cause 100% yield loss in severe early infections. Transmission is very fast (within 5-7 days). It causes severe stunting, yellow-orange discoloration, and major yield loss due to sterilization of grains or poor grain filling.":
            "Ang tungro usa ka seryosong viral na sakit sa humay na ipinapadala ng mga green leafhopper, na nagaganap sa pinakahabang bahagi ng South at Southeast Asia. Una itong kinilala noong 1965 sa IRRI (Pilipinas). Ang sakit ay maaaring magdulot ng hanggang 100% na pagkawala sa ani sa mga grabe na maaga na impeksyon. Ang pagpapadala ay napakabilis (sa loob ng 5-7 na araw). Ito ay nagiging sanhi ng malalaking pagkukulit, dilaw-orange na pagbabago ng kulay, at malaking pagkawala sa ani dahil sa sterilisasyon ng mga bigas o mahinang pag-aani.",
        
        "Leaf smut is a fungal disease found worldwide in rice-growing areas. It forms small, slightly raised black spots on rice leaves that look like pepper dust. While usually a minor disease, severe infection can reduce plant vigor and yield slightly. Heavy infection causes leaves to yellow, dry out, and have dead tips. The disease is typically managed through good farming practices rather than chemicals.":
            "Ang leaf smut usa ka fungal na sakit na makikita sa buong mundo sa mga lugar ng pagtatanim ng humay. Ito ay bumubuo ng mga gagmay, bahagyang nataas na itim na mga tuldok sa mga dahon ng humay na parang pulbos ng paminta. Habang karaniwang minor lamang ang sakit, ang mabigat na impeksyon ay maaaring bumawas ng lakas ng tanom at ani. Ang mabigat na impeksyon ay nagdudulot ng pag-iwan ng mga dahon, pag-aaraw, ug patay na mga dulo. Ang sakit ay karaniwang inakatalga sa pamamagitan ng magandang pagsasaka sa halip na kemikal.",
        
        # Detailed Cebuano explanations for Bacterial Blight
        "Ang Bacterial blight maoy hinungdan sa pagkalaya sa mga semilya ug ang pagdalag ug pagkapatay sa mga dahon.":
            "Ang Bacterial blight maoy hinungdan sa pagkalaya sa mga semilya ug ang pagdalag ug pagkapatay sa mga dahon.",
        "Dako ang posibilidad da maugmad kini sa mga dapit nga adunay mga sagbot ug tuod sa mga nataptan na tanom.":
            "Dako ang posibilidad na maugmad kini sa mga dapit nga adunay mga sagbot ug tuod sa mga nataptan na tanom.",
        "Mahitabo kini sa tropikal ug bugnaw na mga palibot, ilabi na sa mga dapit nga adunay irigasyon ug mga ulanon na kapatagan.":
            "Mahitabo kini sa tropikal ug bugnaw na mga palibot, ilabi na sa mga dapit nga adunay irigasyon ug mga ulanon na kapatagan.",
        "Kasagaran kini makita kon adunay kusog nga hangin ug sige-sige na ulan.":
            "Kasagaran kini makita kon adunay kusog nga hangin ug sige-sige na ulan.",
        "Tan-awa kon aduna bay pagkalaya ug pagdalag sa mga dahon, o pagkalaya sa mga semilya (gitawag usab og kresek).":
            "Tan-awa kon aduna bay pagkalaya ug pagdalag sa mga dahon, o pagkalaya sa mga semilya (gitawag usab og kresek).",
        "Sa mga semilya, ang mga nataptan na dahon mahimong grayish-green ug maglukot.":
            "Sa mga semilya, ang mga nataptan na dahon mahimong grayish-green ug maglukot.",
        "Samtang nagkagrabe ang sakit, mahimong dalag ngadto sa kolor-uhot ang mga dahon ug malaya, hinungdan nga mamatay ang tibuok semilya.":
            "Samtang nagkagrabe ang sakit, mahimong dalag ngadto sa kolor-uhot ang mga dahon ug malaya, hinungdan nga mamatay ang tibuok semilya.",
        "Para mailhan ang kresek gikan sa kadaot sa stem borer, pispisa o pigaa ang ubos na tumoy sa semilya.":
            "Para mailhan ang kresek gikan sa kadaot sa stem borer, pispisa o pigaa ang ubos na tumoy sa semilya.",
        "Kon kresek, adunay mugawas na dalag na duga sa bakterya (bacterial ooze).":
            "Kon kresek, adunay mugawas na dalag na duga sa bakterya (bacterial ooze).",
        "Ang pagtanom og mga barayti na lig-on batok sa sakit mao ang labing epektibo ug barato na paagi.":
            "Ang pagtanom og mga barayti na lig-on batok sa sakit mao ang labing epektibo ug barato na paagi.",
        "Siguraduhon ang maayong agianan sa tubig (drainage) sa kaumahan.":
            "Siguraduhon ang maayong agianan sa tubig (drainage) sa kaumahan.",
        "Huptang limpyo ang umahan; kuhaa ang mga sagbot ug daruhon ang mga tuod sa humay aron mamatay ang mga bakterya.":
            "Huptang limpyo ang umahan; kuhaa ang mga sagbot ug daruhon ang mga tuod sa humay aron mamatay ang mga bakterya.",
        
        # Detailed Cebuano explanations for Leaf Blast
        "Takdan niiti ang tanang bahin sa tanom na anaa sa ibabaw sa yuta sama sa dahon, node, ug liog sa humay (neck).":
            "Takdan niiti ang tanang bahin sa tanom na anaa sa ibabaw sa yuta sama sa dahon, node, ug liog sa humay (neck).",
        "Ang mga fungal spores mokatap pinaagi sa hangin.":
            "Ang mga fungal spores mokatap pinaagi sa hangin.",
        "Paborable kini sa bugnaw na temperatura, sige-sige na ulan, ug taas na humidity.":
            "Paborable kini sa bugnaw na temperatura, sige-sige na ulan, ug taas na humidity.",
        "Adunay gagmay na puti o gray-green na mga spots na naay itom na kilid.":
            "Adunay gagmay na puti o gray-green na mga spots na naay itom na kilid.",
        "Kini mahimong pormang spindle o diamond na naay gray na tunga ug brown na kilid.":
            "Kini mahimong pormang spindle o diamond na naay gray na tunga ug brown na kilid.",
        "Paggamit og resistant na mga barayti, saktong pag-abono (likayan ang sobra na nitroheno), ug paggamit og systemic na mga fungicides kon gikinahanglan.":
            "Paggamit og resistant na mga barayti, saktong pag-abono (likayan ang sobra na nitroheno), ug paggamit og systemic na mga fungicides kon gikinahanglan.",
        
        # Detailed Cebuano explanations for Brown Spot
        "Kini usa ka fungal pathogen na motakod sa mga dahon, panicles, ug mga liso.":
            "Kini usa ka fungal pathogen na motakod sa mga dahon, panicles, ug mga liso.",
        "Kini hinungdan sa brown na mga lama sa dahon ug dili maayo na pagkapuno sa lugas.":
            "Kini hinungdan sa brown na mga lama sa dahon ug dili maayo na pagkapuno sa lugas.",
        "Kasagaran kini sa mga yuta na kulang sa sustansya o mga humay na na-stress.":
            "Kasagaran kini sa mga yuta na kulang sa sustansya o mga humay na na-stress.",
        "Sa mga hamtong na dahon, makita ang pormang oval na mga lama na adunay gray na tunga ug reddish-brown na kilid.":
            "Sa mga hamtong na dahon, makita ang pormang oval na mga lama na adunay gray na tunga ug reddish-brown na kilid.",
        "Pauswagon ang kasanag o sustansya sa yuta pinaagi sa balanse na pag-abono ug paggamit og silicon.":
            "Pauswagon ang kasanag o sustansya sa yuta pinaagi sa balanse na pag-abono ug paggamit og silicon.",
        
        # Detailed Cebuano explanations for Leaf Smut
        "Gagmay na itom na mga spots sa duha ka kilid sa dahon na murag itom na paminta.":
            "Gagmay na itom na mga spots sa duha ka kilid sa dahon na murag itom na paminta.",
        "Kasagaran dili kini grabe apan makaapekto sa photosynthesis kon daghan na kaayo ang spots.":
            "Kasagaran dili kini grabe apan makaapekto sa photosynthesis kon daghan na kaayo ang spots.",
        "Kanunay na paghinlo sa umahan ug pagtangtang sa mga nataptan na debris.":
            "Kanunay na paghinlo sa umahan ug pagtangtang sa mga nataptan na debris.",
        
        # Detailed Cebuano for Bacterial Blight - What it does
        "Ang Bacterial blight gipahinabo sa Xanthomonas oryzae pv. oryzae. Kini maoy hinungdan sa pagkalaya sa mga semilya ug ang pagdalag ug pagkaputi sa mga dahon.":
            "Ang Bacterial blight gipahinabo sa Xanthomonas oryzae pv. oryzae. Kini maoy hinungdan sa pagkalaya sa mga semilya ug ang pagdalag ug pagkaputi sa mga dahon.",
        
        # Detailed Cebuano for Bacterial Blight - Why and where
        "Ang sakit lagmit maugmad sa mga dapit nga adunay mga sagbot ug tuod sa mga nataptan na tanom. Mahimo kini mahitabo sa tropikal ug bugnaw na mga palibot, ilabi na sa mga dapit nga adunay irigasyon ug mga ulanon na kapatagan. Sa kinatibuk-an, ang sakit ganahan sa temperatura na 25−34°C, nga adunay relative humidity na labaw sa 70%. Kasagaran kini makita kon adunay kusog na hangin ug sige-sige na ulan, nga nagtugot sa bakterya nga dali rang mokatap pinaagi sa mga tulo sa duga (ooze droplets) sa mga samad sa nataptan na tanom. Ang Bacterial blight mahimong grabe sa mga barayti nga daling matakdan ilalom sa taas na pag-abono sa nitroheno.":
            "Ang sakit lagmit maugmad sa mga dapit nga adunay mga sagbot ug tuod sa mga nataptan na tanom. Mahimo kini mahitabo sa tropikal ug bugnaw na mga palibot, ilabi na sa mga dapit nga adunay irigasyon ug mga ulanon na kapatagan. Sa kinatibuk-an, ang sakit ganahan sa temperatura na 25−34°C, nga adunay relative humidity na labaw sa 70%. Kasagaran kini makita kon adunay kusog na hangin ug sige-sige na ulan, nga nagtugot sa bakterya nga dali rang mokatap pinaagi sa mga tulo sa duga (ooze droplets) sa mga samad sa nataptan na tanom. Ang Bacterial blight mahimong grabe sa mga barayti nga daling matakdan ilalom sa taas na pag-abono sa nitroheno.",
        
        # Detailed Cebuano for Bacterial Blight - Identification
        "Tan-awa kon aduna bay pagkalaya ug pagdalag sa mga dahon, o pagkalaya sa mga semilya (gitawag usab og kresek). Sa mga semilya, ang mga nataptan na dahon mahimong grayish green ug maglukot. Samtang nagkagrabe ang sakit, ang mga dahon mahimong dalag ngadto sa kolor-uhot ug malaya, hinungdan nga mamatay ang tibuok semilya. Ang kresek sa mga semilya usahay masaypan nga kadaot sa sayo na rice stem borer. Aron mailhan ang kresek gikan sa kadaot sa stem borer, pigaa ang ubos na tumoy sa nataptan na semilya pinaagi sa mga tudlo. Ang kresek kinahanglang magpakita og dalag na duga sa bakterya nga mogawas sa giputlan na bahin. Dili sama sa mga tanom nga gikaon sa stem borer, ang mga humay nga adunay kresek dili dali maibot gikan sa yuta.":
            "Tan-awa kon aduna bay pagkalaya ug pagdalag sa mga dahon, o pagkalaya sa mga semilya (gitawag usab og kresek). Sa mga semilya, ang mga nataptan na dahon mahimong grayish green ug maglukot. Samtang nagkagrabe ang sakit, ang mga dahon mahimong dalag ngadto sa kolor-uhot ug malaya, hinungdan nga mamatay ang tibuok semilya. Ang kresek sa mga semilya usahay masaypan nga kadaot sa sayo na rice stem borer. Aron mailhan ang kresek gikan sa kadaot sa stem borer, pigaa ang ubos na tumoy sa nataptan na semilya pinaagi sa mga tudlo. Ang kresek kinahanglang magpakita og dalag na duga sa bakterya nga mogawas sa giputlan na bahin. Dili sama sa mga tanom nga gikaon sa stem borer, ang mga humay nga adunay kresek dili dali maibot gikan sa yuta.",
        
        # Detailed Cebuano for Bacterial Blight - Lesions
        "Tan-awa kon aduna bay mga samad (lesions): Sa mas karaan na mga tanom, ang mga samad kasagarang maugmad ingon nga water-soaked ngadto sa yellow-orange na mga badlis sa dahon o sa tumoy sa dahon, o sa mga bahin sa dahon nga nasamdan. Ang mga samad adunay bawog-bawog (wavy) na kilid ug mopaingon sa punoan sa dahon. Sa mga bag-ong samad, ang duga sa bakterya na morag gatas na yamog makita sa sayo sa buntag. Ang duga sa bakterya madugay mamala ug mahimong gagmay na dalag na mga beads sa ilawom sa dahon.":
            "Tan-awa kon aduna bay mga samad (lesions): Sa mas karaan na mga tanom, ang mga samad kasagarang maugmad ingon nga water-soaked ngadto sa yellow-orange na mga badlis sa dahon o sa tumoy sa dahon, o sa mga bahin sa dahon nga nasamdan. Ang mga samad adunay bawog-bawog (wavy) na kilid ug mopaingon sa punoan sa dahon. Sa mga bag-ong samad, ang duga sa bakterya na morag gatas na yamog makita sa sayo sa buntag. Ang duga sa bakterya madugay mamala ug mahimong gagmay na dalag na mga beads sa ilawom sa dahon.",
        
        # Detailed Cebuano for Bacterial Blight - Old lesions and diagnosis
        "Ang karaan na mga samad mahimong dalag ngadto sa grayish white na adunay itom na mga tuldok tungod sa pagtubo sa nagkalain-laing saprophytic fungi. Sa grabe na pagkatakod, ang mga samad mahimong moabot sa leaf sheath.":
            "Ang karaan na mga samad mahimong dalag ngadto sa grayish white na adunay itom na mga tuldok tungod sa pagtubo sa nagkalain-laing saprophytic fungi. Sa grabe na pagkatakod, ang mga samad mahimong moabot sa leaf sheath.",
        
        # Detailed Cebuano for Bacterial Blight - Quick diagnosis
        "Aron dali na madayagnos ang bacterial blight sa dahon: putla ang usa ka bag-ong samad ug ibutang sa usa ka transparent na sudlanan na adunay limpyo na tubig. Human sa pipila ka minuto, ituyhad ang sudlanan batok sa kasega ug tan-awa kon aduna bay baga o hanap na likido na mogawas gikan sa pinutlan na tumoy sa dahon.":
            "Aron dali na madayagnos ang bacterial blight sa dahon: putla ang usa ka bag-ong samad ug ibutang sa usa ka transparent na sudlanan na adunay limpyo na tubig. Human sa pipila ka minuto, ituyhad ang sudlanan batok sa kasega ug tan-awa kon aduna bay baga o hanap na likido na mogawas gikan sa piputlan na tumoy sa dahon.",
        
        # Detailed Cebuano for Bacterial Blight - Why important
        "Ang Bacterial blight usa sa labing seryoso na mga sakit sa humay. Kon mas sayo mahitabo ang sakit, mas taas ang pagkawala sa abot. Ang pagkawala sa abot tungod niini mahimong moabot sa 70% kon mogamit og mga barayti nga daling matakdan sa mga palibot na paborable sa sakit. Kon ang mga tanom matakdan sa booting stage, ang sakit dili makaapekto sa gidaghanon sa abot apan moresulta kini sa dili maayo na kalidad sa lugas ug daghang tipaka na humay.":
            "Ang Bacterial blight usa sa labing seryoso na mga sakit sa humay. Kon mas sayo mahitabo ang sakit, mas taas ang pagkawala sa abot. Ang pagkawala sa abot tungod niini mahimong moabot sa 70% kon mogamit og mga barayti nga daling matakdan sa mga palibot na paborable sa sakit. Kon ang mga tanom matakdan sa booting stage, ang sakit dili makaapekto sa gidaghanon sa abot apan moresulta kini sa dili maayo na kalidad sa lugas ug daghang tipaka na humay.",
        
        # Detailed Cebuano for Bacterial Blight - Management
        
        # Sheath Blight translations
        "Sheath Blight (Rice Sheath Blight Disease)": "Sheath Blight (Sakit sa Liog ng Humay)",
        "Moderate to High": "Katamtaman hanggang Taas",
        "Monitor closely and manage early to prevent spread": "Bantayi nang mabuti at pamahalaan nang maaga upang maiwasan ang pagkaylap",
        "Greenish-gray lesions on leaf sheaths in early stage": "Abumadong-greish na mga samad sa liog ng dahon nang maaga",
        "Lesions enlarge and turn brown with gray centers in mid-stage": "Lumaki ang mga samad at nagiging brown na may gray na tunga sa gitna ng panahon",
        "Dark borders around lesions in advanced stage": "Madilim na hangganan sa paligid ng mga samad sa advanced stage",
        "Spread to leaves causing yellowing in severe stage": "Kumalat sa mga dahon na nagiging dilaw sa grabe na entablado",
        "Plant rot and decay in heavily infected plants": "Pagkabulok at pagkasira ng tanom sa lubhang nakahawang mga tanim",
        "Lesions may spread up the plant affecting multiple plants": "Ang mga samad ay maaaring kumalat sa taas ng tanom at makaapekto sa maraming tanim",
        "Affected areas show progressive tissue death": "Ang mga apektadong lugar ay nagpapakita ng patuloy na pagkamatay ng tisyu",
        "Water-soaked appearance initially on sheaths": "Parang basang-basa na hitsura sa simula sa liog ng dahon",
        "Sheath blight is caused by a soil-borne fungus and spreads through contact with infected plants and water. In early stages, greenish-gray lesions appear on leaf sheaths.": "Ang sheath blight ay dulot ng fungus na nanggagaling sa lupa at kumakalat sa pamamagitan ng makikipag-ugnayan sa nakahawang mga tanim at tubig. Sa unang yugto, abumadong-grayish na mga samad ay lumilitaw sa liog ng dahon.",
        "Scout fields regularly for early lesions": "Tuklasin ang mga bukid nang regular para sa maagagang mga samad",
        "Remove heavily infected plants if practical": "Alisin ang lubhang nakahawang mga tanim kung praktikal",
        "Reduce excessive nitrogen application": "Bawasan ang labis na paggamit ng nitrogen",
        "Apply fungicides if disease is spreading rapidly": "Gumamit ng fungicide kung ang sakit ay mabilis kumakalat",
        "Improve field drainage to reduce moisture": "Pagbutihin ang pag-drenahe ng bukid upang mabawasan ang kalamigan",
        "Avoid contact between infected and healthy plants": "Iwasan ang pakikipag-ugnayan sa pagitan ng nakahawang at malusog na mga tanim",
        "Follow local agricultural office recommendations": "Sundin ang mga rekomendasyon ng lokal na opisina ng pagsasaka",
        "Avoid excessive nitrogen which increases disease risk": "Iwasan ang labis na nitrogen na nagpapataas ng panganganib ng sakit",
        "Use balanced fertilizer application": "Gumamit ng balanseng paggamit ng pataba",
        "Apply nutrients at appropriate timing": "Magbigay ng nutrient sa naaangkop na oras",
        "Avoid stress from nutrient deficiency": "Iwasan ang stress mula sa kakulangan ng nutrient",
        "Use split applications rather than single heavy application": "Gumamit ng hihiwalay na paggamit sa halip na isang mabigat na paggamit",
        
        # Bacterial Blight sheath blight steps
        "Rhizoctonia solani (fungus)": "Rhizoctonia solani (fungus)",
        "Soil-borne fungus": "Fungus na nanggagaling sa lupa",
        "Spreads through contact with infected plants and water": "Kumakalat sa pamamagitan ng makikipag-ugnayan sa nakahawang mga tanim at tubig",
        
        # General disease terms
        "Moderate": "Katamtaman",
        "Causal agent": "Sanhi ng sakit",
        "Explanation": "Paliwanag",
        "Next steps": "Susunod na hakbang",
        "When to contact": "Kailan makipag-ugnayan",
        "disease": "sakit",
        "rice": "humay",
        "fungus": "fungus",
        "bacteria": "bakterya",
        "fields": "mga bukid",
        "plants": "mga tanim",
        "lesions": "mga samad",
        "leaves": "mga dahon",
        "yield": "ani",
        "loss": "pagkawala",
        "water": "tubig",
        "nitrogen": "nitrogen",
        "fungicides": "fungicide",
        "agriculture": "pagsasaka","recommendations": "mga rekomendasyon",
        "approved": "aprubado",
        "office": "opisina",
        "Ang pagtanom og mga barayti nga dili daling matakdan napamatud-an na labing epektibo, kasaligan, ug barato na paagi sa pagkontrol sa bacterial blight. Ang uban pang mga kapilian sa pagkontrol naglakip sa: paggamit og balanse na gidaghanon sa mga sustansya sa tanom, ilabi na ang nitroheno; pagsiguro sa maayong agianan sa tubig sa kaumahan ug sa nursery; pagpabilin na limpyo sa umahan; pagtangtang sa mga sagbot na mahimong kapuy-an sa bakterya ug pagdaro sa mga tuod, uhot, ug uban pang mga salin sa humay; ug pagpauga sa mga umahan na wala gitamnan aron mapugngan ang mga hinungdan sa sakit sa yuta ug sa salin sa tanom.":
            "Ang pagtanom og mga barayti nga dili daling matakdan napamatud-an na labing epektibo, kasaligan, ug barato na paagi sa pagkontrol sa bacterial blight. Ang uban pang mga kapilian sa pagkontrol naglakip sa: paggamit og balanse na gidaghanon sa mga sustansya sa tanom, ilabi na ang nitroheno; pagsiguro sa maayong agianan sa tubig sa kaumahan ug sa nursery; pagpabilin na limpyo sa umahan; pagtangtang sa mga sagbot na mahimong kapuy-an sa bakterya ug pagdaro sa mga tuod, uhot, ug uban pang mga salin sa humay; ug pagpauga sa mga umahan na wala gitamnan aron mapugngan ang mga hinungdan sa sakit sa yuta ug sa salin sa tanom.",
        
        # Leaf Blast - What it does
        "Gipahinabo sa fungus na Magnaporthe oryzae. Motakod kini sa tanang bahin sa tanom sa ibabaw sa yuta: dahon, collar, nodes, ug panicles (neck ug branches). Kini moresulta sa kamatayon sa tisyu ug pagkunhod sa abot.":
            "Gipahinabo sa fungus na Magnaporthe oryzae. Motakod kini sa tanang bahin sa tanom sa ibabaw sa yuta: dahon, collar, nodes, ug panicles (neck ug branches). Kini moresulta sa kamatayon sa tisyu ug pagkunhod sa abot.",
        
        # Leaf Blast - Why and where
        "Makita bisan asa nga adunay blast spores. Paborable kini sa: bugnaw na temperatura, sige-sige na ulan, taas na humidity, mubo na kaumag sa yuta (upland conditions), ug dagkong kalainan sa temperatura sa adlaw ug gabii (formation sa yamog).":
            "Makita bisan asa nga adunay blast spores. Paborable kini sa: bugnaw na temperatura, sige-sige na ulan, taas na humidity, mubo na kaumag sa yuta (upland conditions), ug dagkong kalainan sa temperatura sa adlaw ug gabii (formation sa yamog).",
        
        # Leaf Blast - Identification
        "Gagmay na puti/gray-green na mga spots na adunay itom na kilid. Mahimong spindle-shaped na mga samad na adunay gray na tunga ug brown na kilid. Ang mga samad mahimong mag-usa ug mopatay sa dahon. Ang Collar blast mahitabo sa punoan sa dahon, hinungdan sa kamatayon sa dahon ug pagkahuyang sa tanom.":
            "Gagmay na puti/gray-green na mga spots na adunay itom na kilid. Mahimong spindle-shaped na mga samad na adunay gray na tunga ug brown na kilid. Ang mga samad mahimong mag-usa ug mopatay sa dahon. Ang Collar blast mahitabo sa punoan sa dahon, hinungdan sa kamatayon sa dahon ug pagkahuyang sa tanom.",
        
        # Leaf Blast - Why important
        "Usa sa labing makadaot na sakit sa humay sa tibuok kalibutan. Ang sayo na impeksyon makapatay sa mga semilya. Ang grabe na impeksyon makapamenos sa leaf area ug moresulta sa dili maayo na pagkapuno sa lugas.":
            "Usa sa labing makadaot na sakit sa humay sa tibuok kalibutan. Ang sayo na impeksyon makapatay sa mga semilya. Ang grabe na impeksyon makapamenos sa leaf area ug moresulta sa dili maayo na pagkapuno sa lugas.",
        
        # Leaf Blast - Management
        "Ang labing maayo na kontrol mao ang resistant na mga barayti. Pagdumala sa tanom pinaagi sa pag-adjust sa panahon sa pagtanom, paglikay sa sobra na nitroheno, ug paggamit og balanse na mga sustansya ug silicon.":
            "Ang labing maayo na kontrol mao ang resistant na mga barayti. Pagdumala sa tanom pinaagi sa pag-adjust sa panahon sa pagtanom, paglikay sa sobra na nitroheno, ug paggamit og balanse na mga sustansya ug silicon.",
        
        # Brown Spot - What it does
        "Kini usa ka fungal pathogen na motakod sa mga dahon, panicles, ug mga lugas. Moresulta kini sa brown na mga lama sa dahon ug dili maayo na pagkapuno sa lugas.":
            "Kini usa ka fungal pathogen na motakod sa mga dahon, panicles, ug mga lugas. Moresulta kini sa brown na mga lama sa dahon ug dili maayo na pagkapuno sa lugas.",
        
        # Brown Spot - Why and where
        "Kasagaran kini sa mga yuta na kulang sa sustansya o mga humay na na-stress.":
            "Kasagaran kini sa mga yuta na kulang sa sustansya o mga humay na na-stress.",
        
        # Brown Spot - Identification
        "Sa mga hamtong na dahon, makita ang oval na mga lama na adunay gray na tunga ug reddish-brown na kilid.":
            "Sa mga hamtong na dahon, makita ang oval na mga lama na adunay gray na tunga ug reddish-brown na kilid.",
        
        # Brown Spot - Management
        "Pauswagon ang sustansya sa yuta pinaagi sa balanse na pag-abono ug paggamit og silicon.":
            "Pauswagon ang sustansya sa yuta pinaagi sa balanse na pag-abono ug paggamit og silicon.",
        
        # Leaf Smut - Identification
        "Gagmay na itom na mga spots sa duha ka kilid sa dahon na morag itom na paminta.":
            "Gagmay na itom na mga spots sa duha ka kilid sa dahon na morag itom na paminta.",
        
        # Leaf Smut - Impact
        "Kasagaran kini dili grabe apan makaapekto sa photosynthesis kon daghan na kaayo ang spots.":
            "Kasagaran kini dili grabe apan makaapekto sa photosynthesis kon daghan na kaayo ang spots.",
        
        # Leaf Smut - Management
        "Kanunay na paghinlo sa umahan ug pagtangtang sa mga nataptan na debris.":
            "Kanunay na paghinlo sa umahan ug pagtangtang sa mga nataptan na debris.",
        
        # Sheath Blight information
        "Sheath Blight": "Sheath Blight",
        "Soil-borne fungus and infected plant debris": "Soil-borne fungus at mga nataptan na debris",
        "Greenish-gray lesions on leaf sheaths in early stage": "Berde-gray na mga samad sa leaf sheath sa sayo na yugto",
        "Lesions enlarge and turn brown with gray centers in mid-stage": "Ang mga samad moalak at mahimong brown na adunay gray na tunga sa gitna-gitna na yugto",
        "Dark borders around lesions in advanced stage": "Itom na boundary sa paligid sa mga samad sa advanced stage",
        "Spread to leaves causing yellowing in severe stage": "Pagkalat sa mga dahon na nagdudulot ng pagkanilaw sa grabe na yugto",
        "Plant rot and decay in heavily infected plants": "Pagkabusog at pagkabulok sa tanom sa grabeng natakdan",
    }
    return translations.get(text, text)

def _detect_intents(msg: str) -> set[str]:
    m = (msg or "").lower()

    intents = set()

    symptom_kw = ["symptom", "symptoms", "sign", "signs", "look like", "appearance", "spot", "streak", "lesion", "sintomas"]
    cause_kw = ["cause", "causes", "why", "reason", "source", "what caused", "hinungdan", "rason"]
    prevent_kw = ["prevent", "prevention", "avoid", "stop", "reduce", "protect", "paglikay", "likayi", "pugngan"]
    treat_kw = ["treat", "treatment", "cure", "spray", "fungicide", "bactericide", "chemical", "medicine", "control", "manage", "tambal", "pagtambal"]
    fert_kw = ["fertil", "fertilizer", "npk", "urea", "nitrogen", "potassium", "phosphorus", "k ", "n ", "abono", "pataba"]

    if any(k in m for k in symptom_kw): intents.add("symptoms")
    if any(k in m for k in cause_kw): intents.add("causes")
    if any(k in m for k in prevent_kw): intents.add("prevention")
    if any(k in m for k in treat_kw): intents.add("treatment_plan")
    if any(k in m for k in fert_kw): intents.add("fertilizer_guidance")

    # quick command style
    if m.strip() in ["symptoms", "causes", "prevention", "treatment", "fertilizer", "sintomas", "hinungdan", "paglikay", "tambal", "abono"]:
        mapping = {
            "symptoms": "symptoms",
            "causes": "causes",
            "prevention": "prevention",
            "treatment": "treatment_plan",
            "fertilizer": "fertilizer_guidance",
            "sintomas": "symptoms",
            "hinungdan": "causes",
            "paglikay": "prevention",
            "tambal": "treatment_plan",
            "abono": "fertilizer_guidance",
        }
        intents.add(mapping[m.strip()])

    return intents

def _format_list(title: str, items: list[str], language: str, section_type: str = "steps") -> str:
    translated_title = _translate_text(title, language)
    if not items:
        if section_type == "bullets":
            return f"{translated_title}:\n• {_translate_text('N/A', language)}"
        else:
            step_label = _translate_text('Step ', language)
            return f"{translated_title}:\n{step_label}1: {_translate_text('N/A', language)}"
    formatted_items = []
    
    if section_type == "bullets":
        # Format as bullet points for fertilizer guidance
        for item in items:
            tx_item = _translate_text(item, language)
            # Keep items short - max 100 chars per item
            if len(tx_item) > 100:
                tx_item = tx_item[:100] + "..."
            formatted_items.append(f"• {tx_item}")
    else:
        # Format as steps for Disease Management Strategy
        step_label = _translate_text('Step ', language)
        for idx, item in enumerate(items, 1):
            tx_item = _translate_text(item, language)
            # Keep items short - max 100 chars per item
            if len(tx_item) > 100:
                tx_item = tx_item[:100] + "..."
            formatted_items.append(f"{step_label}{idx}: {tx_item}")
    
    return translated_title + ":\n" + "\n".join(formatted_items)

def _build_reply(disease_key: str, kb: dict, user_msg: str | None, language: str) -> str:
    display = _translate_text(kb.get("display", disease_key.replace("_", " ").title()), language)
    severity = _translate_text(kb.get("severity", "Unknown"), language)
    urgency = _translate_text(kb.get("urgency", "N/A"), language)
    # Shorten explanation to first 2 sentences only
    explanation = kb.get("explanation", "")
    sentences = explanation.split('. ')
    short_explanation = '. '.join(sentences[:2]) + '.' if sentences else explanation
    short_explanation = _translate_text(short_explanation, language)
    
    example_prompt = _translate_text(
        'Example: "symptoms" or "treatment and fertilizer"',
        language,
    )

    header = (
        f"{_translate_text('Disease:', language)} {display}\n"
        f"{_translate_text('Severity:', language)} {severity} | {_translate_text('Urgency:', language)} {urgency}\n\n"
        f"{short_explanation}\n"
    )

    msg = (user_msg or "").strip()
    intents = _detect_intents(msg)

    # If no message or no clear intent, return overview + menu
    if not msg or not intents:
        return (
            header
            + f"\n{_translate_text('You can ask me about:', language)}\n"
              f"  - {_translate_text('symptoms', language)}\n"
              f"  - {_translate_text('causes', language)}\n"
              f"  - {_translate_text('prevention', language)}\n"
              f"  - {_translate_text('treatment', language)}\n"
              f"  - {_translate_text('fertilizer', language)}\n\n"
              f"{example_prompt}"
        )

    parts = [header]

    # If user asked multiple things, include all requested sections
    if "symptoms" in intents:
        parts.append(_format_list("\nSymptoms", kb.get("symptoms", []), language, "bullets"))
    if "causes" in intents:
        parts.append(_format_list("\nCauses", kb.get("causes", []), language, "bullets"))
    if "prevention" in intents:
        parts.append(_format_list("\nPrevention", kb.get("prevention", []), language, "bullets"))
    if "treatment_plan" in intents:
        parts.append(_format_list("\nDisease Management Strategy", kb.get("treatment_plan", []), language, "steps"))
    if "fertilizer_guidance" in intents:
        parts.append(_format_list("\nFertilizer guidance", kb.get("fertilizer_guidance", []), language, "bullets"))

    note = _translate_text("Note: This is general guidance—follow local agriculture office recommendations for chemicals and approved products.", language)
    parts.append(f"\n{note}")
    return "\n".join(parts)

@router.post("/chatbot", response_model=ChatbotOut)
def chatbot(
    payload: ChatbotIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    disease_key = _normalize_disease(payload.disease)
    language = _normalize_language(payload.language)
    # Prefer DB-driven knowledge base (editable later), fallback to static DISEASE_KB.
    kb = disease_from_db(db, disease_key) or DISEASE_KB.get(disease_key)

    if not kb:
        return ChatbotOut(
            disease=disease_key,
            severity=_translate_text("Unknown", language),
            urgency=_translate_text("Please verify the image / label", language),
            explanation=_translate_text("I don't recognize this disease label yet.", language),
            symptoms=[_translate_text("N/A", language)],
            causes=[_translate_text("N/A", language)],
            prevention=[_translate_text("Try a clearer photo in good lighting", language), _translate_text("Capture both close-up and whole leaf", language)],
            treatment_plan=[_translate_text("Avoid chemicals until confirmed", language)],
            fertilizer_guidance=[_translate_text("Use balanced fertilization; avoid excessive nitrogen while unsure", language)],
            next_steps=[_translate_text("Re-scan with a clearer image", language), _translate_text("Consult an agriculture technician", language)],
            when_to_contact=[_translate_text("If symptoms spread quickly", language), _translate_text("If large patches show symptoms", language)],
            reply=_translate_text("Unknown disease label. Try re-scanning or consult your local agriculture officer.", language)
        )

    reply = _build_reply(disease_key, kb, payload.message, language)
    
    # Update disease ranking
    update_disease_ranking(db, disease_key, user_location=current_user.location)
    
    log_activity(
        db,
        user_id=current_user.id,
        action="chatbot.ask",
        detail={"disease": disease_key, "message": payload.message or ""},
        location=current_user.location
    )

    # Keep your schema response fields consistent
    return ChatbotOut(
        disease=disease_key,
        severity=kb["severity"],
        urgency=kb["urgency"],
        explanation=kb["explanation"],
        symptoms=kb["symptoms"],
        causes=kb["causes"],
        prevention=kb["prevention"],
        treatment_plan=kb["treatment_plan"],
        fertilizer_guidance=kb["fertilizer_guidance"],
        next_steps=kb.get("next_steps", []),
        when_to_contact=kb.get("when_to_contact", []),
        reply=reply,
    )

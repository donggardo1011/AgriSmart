import sqlite3
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import Base, engine
from routes.auth_routes import router as auth_router
from config import CORS_ORIGINS
from fastapi.staticfiles import StaticFiles
import uvicorn
from routes.prediction_routes import router as prediction_router
from routes.reset_link_routes import router as reset_link_router
from routes.dataset_routes import router as dataset_router
from routes.dataset_annotation_routes import router as dataset_annotation_router
from routes.admin_insights_routes import router as admin_insights_router
from routes.disease_routes import router as disease_router
from routes.model_routes import router as model_router
from routes.model_routes import ensure_base_model_registered
from routes.backup_routes import router as backup_router
from routes.train_routes import router as train_router
from routes.activity_routes import router as activity_router
from routes.analytics_routes import router as analytics_router
from models import Disease
import json

def _ensure_sqlite_columns():
    # Very small "migration" for local dev SQLite.
    # Adds columns without requiring Alembic.
    try:
        con = sqlite3.connect("users.db")
        cur = con.cursor()

        # Check and add missing columns to users table
        cur.execute("PRAGMA table_info(users)")
        cols = {row[1] for row in cur.fetchall()}
        if "role" not in cols:
            cur.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user'")
        if "location" not in cols:
            cur.execute("ALTER TABLE users ADD COLUMN location TEXT")
        if "last_activity_at" not in cols:
            cur.execute("ALTER TABLE users ADD COLUMN last_activity_at DATETIME")

        # Check and add missing columns to activity_logs table
        cur.execute("PRAGMA table_info(activity_logs)")
        activity_cols = {row[1] for row in cur.fetchall()}
        if "location" not in activity_cols:
            cur.execute("ALTER TABLE activity_logs ADD COLUMN location TEXT")

        # Activate all inactive users (set is_active=1)
        cur.execute("UPDATE users SET is_active = 1 WHERE is_active = 0 OR is_active IS NULL")

        con.commit()
    except Exception as e:
        print("DB MIGRATION WARNING:", repr(e))
    finally:
        try:
            con.close()
        except Exception:
            pass


_ensure_sqlite_columns()
Base.metadata.create_all(bind=engine)

def _seed_diseases():
    # Seed core diseases so AgriBot + "tracked diseases" can be DB-driven.
    # Safe to run on every startup (idempotent by key).
    from database import SessionLocal
    import os

    # Load diseases from diseases_data.json
    diseases_file = os.path.join(os.path.dirname(__file__), 'diseases_data.json')
    diseases_data = {}
    
    if os.path.exists(diseases_file):
        with open(diseases_file, 'r') as f:
            data = json.load(f)
            # Create dict indexed by key for easy lookup
            diseases_data = {disease['key']: disease for disease in data.get('diseases', [])}

    seeds = [
        {
            "key": "bacterial_blight",
            "display_name": "Bacterial Blight",
            "severity": "High",
            "urgency": "Act quickly to prevent spread and yield loss",
            "explanation": "Bacterial blight is a serious bacterial disease caused by Xanthomonas oryzae pv. oryzae that can spread quickly in wet and windy conditions.",
            "causal_agent": "Xanthomonas oryzae pv. oryzae",
            "symptoms_summary_en": diseases_data.get('bacterial_blight', {}).get('symptoms_summary_en', ''),
            "prevention_summary_en": diseases_data.get('bacterial_blight', {}).get('prevention_summary_en', ''),
            "treatment_summary_en": diseases_data.get('bacterial_blight', {}).get('treatment_summary_en', ''),
            "image_url": "/images/diseases/bacterial_blight.jpg",
            "symptoms": [],
            "causes": [],
            "prevention": [],
            "treatment_plan": [],
            "fertilizer_guidance": [],
            "next_steps": [],
            "when_to_contact": [],
        },
        {
            "key": "leaf_blast",
            "display_name": "Leaf Blast",
            "severity": "High",
            "urgency": "Act early because blast can spread quickly",
            "explanation": "Leaf blast is a fungal disease caused by Magnaporthe oryzae that can cause serious leaf damage and yield loss.",
            "causal_agent": "Magnaporthe oryzae",
            "symptoms_summary_en": diseases_data.get('leaf_blast', {}).get('symptoms_summary_en', ''),
            "prevention_summary_en": diseases_data.get('leaf_blast', {}).get('prevention_summary_en', ''),
            "treatment_summary_en": diseases_data.get('leaf_blast', {}).get('treatment_summary_en', ''),
            "image_url": "/images/diseases/leaf_blast.jpg",
            "symptoms": [],
            "causes": [],
            "prevention": [],
            "treatment_plan": [],
            "fertilizer_guidance": [],
            "next_steps": [],
            "when_to_contact": [],
        },
        {
            "key": "brown_spot",
            "display_name": "Brown Spot",
            "severity": "Moderate",
            "urgency": "Monitor closely and manage early if spreading",
            "explanation": "Brown spot is a fungal disease caused by Bipolaris oryzae that produces brown lesions on rice leaves.",
            "causal_agent": "Bipolaris oryzae",
            "symptoms_summary_en": diseases_data.get('brown_spot', {}).get('symptoms_summary_en', ''),
            "prevention_summary_en": diseases_data.get('brown_spot', {}).get('prevention_summary_en', ''),
            "treatment_summary_en": diseases_data.get('brown_spot', {}).get('treatment_summary_en', ''),
            "image_url": "/images/diseases/brown_spot.jpg",
            "symptoms": [],
            "causes": [],
            "prevention": [],
            "treatment_plan": [],
            "fertilizer_guidance": [],
            "next_steps": [],
            "when_to_contact": [],
        },
        {
            "key": "sheath_blight",
            "display_name": "Sheath Blight",
            "severity": "Moderate",
            "urgency": "Manage early and continue monitoring",
            "explanation": "Sheath blight is a fungal disease caused by Rhizoctonia solani that affects leaf sheaths and can reduce yield significantly.",
            "causal_agent": "Rhizoctonia solani",
            "symptoms_summary_en": diseases_data.get('sheath_blight', {}).get('symptoms_summary_en', ''),
            "prevention_summary_en": diseases_data.get('sheath_blight', {}).get('prevention_summary_en', ''),
            "treatment_summary_en": diseases_data.get('sheath_blight', {}).get('treatment_summary_en', ''),
            "image_url": "/images/diseases/sheath_blight.jpg",
            "symptoms": [],
            "causes": [],
            "prevention": [],
            "treatment_plan": [],
            "fertilizer_guidance": [],
            "next_steps": [],
            "when_to_contact": [],
        },
        {
            "key": "tungro",
            "display_name": "Tungro",
            "severity": "High",
            "urgency": "Immediate action is recommended",
            "explanation": "Tungro is a viral disease complex transmitted by green leafhoppers that can cause severe stunting and yield loss.",
            "causal_agent": "Rice Tungro Virus (RTBV + RTSV)",
            "symptoms_summary_en": diseases_data.get('tungro', {}).get('symptoms_summary_en', ''),
            "prevention_summary_en": diseases_data.get('tungro', {}).get('prevention_summary_en', ''),
            "treatment_summary_en": diseases_data.get('tungro', {}).get('treatment_summary_en', ''),
            "image_url": "/images/diseases/tungro.jpg",
            "symptoms": [],
            "causes": [],
            "prevention": [],
            "treatment_plan": [],
            "fertilizer_guidance": [],
            "next_steps": [],
            "when_to_contact": [],
        },
    ]

    db = SessionLocal()
    try:
        # First pass: deactivate and update all existing diseases
        all_existing = db.query(Disease).all()
        for disease in all_existing:
            # Deactivate smut since it's replaced by sheath_blight
            if disease.key == "smut":
                disease.is_active = False
                db.commit()
                continue
            
            # Update any disease that's in our seeds
            seed_match = next((s for s in seeds if s["key"] == disease.key), None)
            if seed_match:
                disease.display_name = seed_match["display_name"]
                disease.explanation = seed_match["explanation"]
                disease.causal_agent = seed_match.get("causal_agent")
                disease.severity = seed_match["severity"]
                disease.urgency = seed_match["urgency"]
                disease.symptoms_summary_en = seed_match.get("symptoms_summary_en")
                disease.prevention_summary_en = seed_match.get("prevention_summary_en")
                disease.treatment_summary_en = seed_match.get("treatment_summary_en")
                disease.image_url = seed_match.get("image_url")
                disease.is_active = True
                db.commit()

        # Second pass: add any missing seeds
        for s in seeds:
            existing = db.query(Disease).filter(Disease.key == s["key"]).first()
            if not existing:
                db.add(
                    Disease(
                        key=s["key"],
                        display_name=s["display_name"],
                        causal_agent=s.get("causal_agent"),
                        severity=s["severity"],
                        urgency=s["urgency"],
                        explanation=s["explanation"],
                        symptoms_summary_en=s.get("symptoms_summary_en"),
                        prevention_summary_en=s.get("prevention_summary_en"),
                        treatment_summary_en=s.get("treatment_summary_en"),
                        image_url=s.get("image_url"),
                        symptoms=json.dumps(s["symptoms"]),
                        causes=json.dumps(s["causes"]),
                        prevention=json.dumps(s["prevention"]),
                        treatment_plan=json.dumps(s["treatment_plan"]),
                        fertilizer_guidance=json.dumps(s["fertilizer_guidance"]),
                        next_steps=json.dumps(s["next_steps"]),
                        when_to_contact=json.dumps(s["when_to_contact"]),
                        is_active=True,
                    )
                )
        db.commit()
    finally:
        db.close()

_seed_diseases()


def _seed_base_model():
    from database import SessionLocal

    db = SessionLocal()
    try:
        ensure_base_model_registered(db)
    finally:
        db.close()


_seed_base_model()


app = FastAPI(title="Capstone Auth API")

app.include_router(reset_link_router)

# Allow Flutter app (debug/web) + allow cookies
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://10.0.2.2:8000",  # not required but ok
        "*"  # for dev only; remove in production
    ],
    allow_credentials=True,  # IMPORTANT for refresh cookie
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(activity_router)
app.include_router(analytics_router)
app.include_router(prediction_router)
app.include_router(dataset_router)
app.include_router(dataset_annotation_router)
app.include_router(admin_insights_router)
app.include_router(disease_router)
app.include_router(model_router)
app.include_router(backup_router)
app.include_router(train_router)

@app.get("/")
def root():
    return {"status": "ok"}

_BACKEND_DIR = os.path.abspath(os.path.dirname(__file__))
app.mount("/uploads", StaticFiles(directory=os.path.join(_BACKEND_DIR, "uploads")), name="uploads")
app.mount("/dataset", StaticFiles(directory=os.path.join(_BACKEND_DIR, "dataset_clean")), name="dataset")


if __name__ == "__main__":
    # Bind to all interfaces so phones on the LAN can reach the API.
    uvicorn.run(app, host="0.0.0.0", port=8000)

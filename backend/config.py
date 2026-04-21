import os
from dotenv import load_dotenv

load_dotenv()

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-me")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
JWT_EXPIRES_MINUTES = int(os.getenv("JWT_EXPIRES_MINUTES", "129600"))  # 90 days instead of 60 minutes

RECAPTCHA_SECRET = os.getenv("RECAPTCHA_SECRET", "")

FRONTEND_RESET_URL = os.getenv("FRONTEND_RESET_URL", "https://agrismartech/reset-password")

SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
SMTP_FROM = os.getenv("SMTP_FROM", SMTP_USER)

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")

CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()]

REFRESH_EXPIRES_DAYS = int(os.getenv("REFRESH_EXPIRES_DAYS", "7"))
COOKIE_SECURE = os.getenv("COOKIE_SECURE", "false").lower() == "true"  # true in HTTPS production
COOKIE_SAMESITE = os.getenv("COOKIE_SAMESITE", "lax")  # "lax" or "none" (none requires secure)

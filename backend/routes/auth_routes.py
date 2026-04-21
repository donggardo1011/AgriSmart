from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone

from database import SessionLocal
from models import User, RefreshSession
from schemas import (
    UserCreate, UserLogin, TokenOut, UserOut,
    ForgotPasswordIn, ResetPasswordIn, ResetPasswordOtpVerifyIn, GoogleLoginIn,
    ChangePasswordIn
)
from auth import (
    hash_password, verify_password,
    create_access_token, decode_token,
    generate_reset_token, hash_token,
    generate_refresh_token, refresh_expires_at,
)
from services.recaptcha import verify_recaptcha, RecaptchaError
from services.email_service import send_email
from services.google_oauth import verify_google_id_token, GoogleAuthError
from config import FRONTEND_RESET_URL, COOKIE_SECURE, COOKIE_SAMESITE, REFRESH_EXPIRES_DAYS
from services.activity_log import log_activity
import random
import string

router = APIRouter(prefix="/auth", tags=["Auth"])
security = HTTPBearer()

def generate_otp() -> str:
    """Generate a random 6-digit OTP code."""
    return ''.join(random.choices(string.digits, k=6))
security_optional = HTTPBearer(auto_error=False)

# -----------------------------
# DB Dependency
# -----------------------------
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# -----------------------------
# Refresh Cookie Helpers
# -----------------------------
def set_refresh_cookie(response: Response, refresh_token: str):
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=COOKIE_SECURE,               # True only on HTTPS production
        samesite=COOKIE_SAMESITE,           # "lax" or "none" (none requires secure)
        path="/auth",                       # cookie only sent to /auth endpoints
        max_age=60 * 60 * 24 * REFRESH_EXPIRES_DAYS,
    )

def clear_refresh_cookie(response: Response):
    response.delete_cookie(key="refresh_token", path="/auth")

# -----------------------------
# JWT Current User Dependency
# -----------------------------
def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    token = creds.credentials
    try:
        sub = decode_token(token)
        user_id = int(sub)
    except Exception as e:
        import traceback
        error_detail = str(e)
        print(f"[AUTH ERROR] Token decode failed: {error_detail}")
        print(f"[AUTH ERROR] Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=401, detail=f"Invalid or expired token: {error_detail}")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        print(f"[AUTH ERROR] User not found for id {user_id}")
        raise HTTPException(status_code=401, detail="User not found")
    
    # Update last activity timestamp
    user.last_activity_at = datetime.utcnow()
    db.commit()
    
    return user


def get_current_user_optional(
    creds: HTTPAuthorizationCredentials | None = Depends(security_optional),
    db: Session = Depends(get_db),
) -> User | None:
    if creds is None:
        return None

    token = creds.credentials
    try:
        sub = decode_token(token)
        user_id = int(sub)
    except Exception:
        return None

    return db.query(User).filter(User.id == user_id).first()

# -----------------------------
# Auth Endpoints
# -----------------------------
@router.post("/register", response_model=UserOut)
async def register(payload: UserCreate, request: Request, db: Session = Depends(get_db)):
    try:
        await verify_recaptcha(payload.recaptcha_token, request.client.host if request.client else None)
    except RecaptchaError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if db.query(User).filter(User.username == payload.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")

    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")

    user = User(
        username=payload.username,
        email=payload.email,
        password=hash_password(payload.password),
        location=payload.location,
        role="user",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    log_activity(db, user_id=user.id, action="auth.register", detail={"username": user.username, "location": payload.location}, location=payload.location)
    return user

@router.post("/login", response_model=TokenOut)
async def login(payload: UserLogin, request: Request, response: Response, db: Session = Depends(get_db)):
    try:
        await verify_recaptcha(payload.recaptcha_token, request.client.host if request.client else None)
    except RecaptchaError as e:
        raise HTTPException(status_code=400, detail=str(e))

    user = db.query(User).filter(User.username == payload.username).first()
    if not user or not user.password:
        raise HTTPException(status_code=400, detail="Invalid username or password")

    print(f"AI DEBUG LOGIN: User found: {user.username}, email: {user.email}")
    print(f"AI DEBUG LOGIN: Password being tested: '{payload.password}'")
    print(f"AI DEBUG LOGIN: Password length: {len(payload.password)}")
    print(f"AI DEBUG LOGIN: Stored hash: {user.password[:50]}...")
    
    if not verify_password(payload.password, user.password):
        print(f"AI DEBUG LOGIN: Password verification failed for user {user.username}")
        raise HTTPException(status_code=400, detail="Invalid username or password")
    
    print(f"AI DEBUG LOGIN: Password verified successfully for user {user.username}")

    # Mark user as active on login and update last activity
    user.is_active = True
    user.last_activity_at = datetime.utcnow()
    db.commit()

    # Access token (short-lived)
    access_token = create_access_token(str(user.id))

    # Refresh token + session (long-lived)
    raw_refresh = generate_refresh_token()
    sess = RefreshSession(
        user_id=user.id,
        refresh_token_hash=hash_token(raw_refresh),
        expires_at=refresh_expires_at().replace(tzinfo=None),  # store naive UTC
        revoked_at=None,
    )
    db.add(sess)
    db.commit()

    set_refresh_cookie(response, raw_refresh)
    log_activity(db, user_id=user.id, action="auth.login", detail={"username": user.username}, location=user.location)
    return TokenOut(access_token=access_token)

@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)):
    return current_user

# -----------------------------
# Forgot / Reset Password
# -----------------------------
@router.post("/forgot-password")
async def forgot_password(payload: ForgotPasswordIn, request: Request, db: Session = Depends(get_db)):
    try:
        await verify_recaptcha(payload.recaptcha_token, request.client.host if request.client else None)
    except RecaptchaError as e:
        raise HTTPException(status_code=400, detail=str(e))

    user = db.query(User).filter(User.email == payload.email).first()

    # always generic response for security
    if not user:
        return {"message": "If the email exists, a reset code has been sent."}

    # Generate 6-digit OTP
    otp_code = generate_otp()
    user.reset_token_hash = otp_code  # Store OTP directly (not hashed for easy comparison)
    user.reset_token_expires_at = datetime.utcnow() + timedelta(minutes=10)
    db.commit()

    subject = "Your password reset code"
    body = f"Your password reset code is: {otp_code}\n\nThis code expires in 10 minutes.\n\nDo not share this code with anyone."

    try:
        send_email(user.email, subject, body)
        return {"message": "If the email exists, a reset code has been sent."}
    except Exception as e:
        print("EMAIL SEND FAILED:", repr(e))
        raise HTTPException(status_code=500, detail=f"Email failed: {e}")


@router.post("/reset-password")
def reset_password(payload: ResetPasswordIn, db: Session = Depends(get_db)):
    token_h = hash_token(payload.token)
    user = db.query(User).filter(User.reset_token_hash == token_h).first()

    if not user:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    if not user.reset_token_expires_at or user.reset_token_expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    user.password = hash_password(payload.new_password)
    user.reset_token_hash = None
    user.reset_token_expires_at = None
    db.commit()

    return {"message": "Password reset successful"}


@router.post("/verify-reset-otp")
def verify_reset_otp(payload: ResetPasswordOtpVerifyIn, db: Session = Depends(get_db)):
    """Verify OTP code and reset password."""
    user = db.query(User).filter(User.email == payload.email).first()

    if not user:
        raise HTTPException(status_code=400, detail="Invalid email or OTP")

    # Check if OTP exists and is not expired
    if not user.reset_token_hash or not user.reset_token_expires_at:
        raise HTTPException(status_code=400, detail="Invalid email or OTP")

    if user.reset_token_expires_at < datetime.utcnow():
        user.reset_token_hash = None
        user.reset_token_expires_at = None
        db.commit()
        raise HTTPException(status_code=400, detail="OTP has expired")

    # Verify OTP code
    if user.reset_token_hash != payload.otp_code.strip():
        print(f"AI DEBUG: OTP mismatch - expected '{user.reset_token_hash}', got '{payload.otp_code.strip()}'")
        raise HTTPException(status_code=400, detail="Invalid email or OTP")

    # OTP is valid, update password
    print(f"AI DEBUG: Resetting password for user {payload.email}")
    print(f"AI DEBUG: Old password hash: {user.password[:30] if user.password else 'NONE'}...")
    print(f"AI DEBUG: User ID: {user.id}, Username: {user.username}")
    
    new_password_hash = hash_password(payload.new_password)
    print(f"AI DEBUG: New password provided: '{payload.new_password}'")
    print(f"AI DEBUG: New password hash created: {new_password_hash[:50]}...")
    
    user.password = new_password_hash
    user.reset_token_hash = None
    user.reset_token_expires_at = None
    
    print(f"AI DEBUG: User object after assignment: password={user.password[:30] if user.password else 'NONE'}...")
    
    # Try explicit flush before commit
    db.flush()
    print(f"AI DEBUG: Flush done")
    
    db.commit()
    print(f"AI DEBUG: Commit done")
    
    # Verify it was saved
    db.refresh(user)
    print(f"AI DEBUG: After refresh: password={user.password[:30] if user.password else 'NONE'}...")
    
    # Double-check by querying fresh
    verification_user = db.query(User).filter(User.email == payload.email).first()
    print(f"AI DEBUG: Fresh query result: password={verification_user.password[:30] if verification_user.password else 'NONE'}...")
    
    print(f"AI DEBUG: Password reset successful for user {payload.email}")

    return {"message": "Password reset successful"}

# -----------------------------
# Google Login (id_token)
# -----------------------------
@router.post("/google", response_model=TokenOut)
async def google_login(payload: GoogleLoginIn, request: Request, response: Response, db: Session = Depends(get_db)):
    try:
        await verify_recaptcha(payload.recaptcha_token, request.client.host if request.client else None)
    except RecaptchaError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        info = verify_google_id_token(payload.id_token)
    except GoogleAuthError as e:
        raise HTTPException(status_code=400, detail=str(e))

    email = info.get("email")
    sub = info.get("sub")
    if not email or not sub:
        raise HTTPException(status_code=400, detail="Google token missing email/sub")

    user = db.query(User).filter((User.google_sub == sub) | (User.email == email)).first()

    if not user:
        # auto-register
        username = (email.split("@")[0])[:50]
        base = username
        i = 1
        while db.query(User).filter(User.username == username).first():
            i += 1
            username = f"{base}{i}"[:50]

        user = User(
            username=username,
            email=email,
            google_sub=sub,
            password=None,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        if not user.google_sub:
            user.google_sub = sub
            db.commit()

    # issue tokens
    access_token = create_access_token(str(user.id))

    raw_refresh = generate_refresh_token()
    sess = RefreshSession(
        user_id=user.id,
        refresh_token_hash=hash_token(raw_refresh),
        expires_at=refresh_expires_at().replace(tzinfo=None),
        revoked_at=None,
    )
    db.add(sess)
    db.commit()

    set_refresh_cookie(response, raw_refresh)
    return TokenOut(access_token=access_token)

# -----------------------------
# Refresh / Logout
# -----------------------------
@router.post("/refresh", response_model=TokenOut)
def refresh(request: Request, db: Session = Depends(get_db)):
    raw = request.cookies.get("refresh_token")
    if not raw:
        raise HTTPException(status_code=401, detail="Missing refresh token")

    token_h = hash_token(raw)
    sess = db.query(RefreshSession).filter(RefreshSession.refresh_token_hash == token_h).first()
    if not sess:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    if sess.revoked_at is not None:
        raise HTTPException(status_code=401, detail="Refresh token revoked")

    if sess.expires_at < datetime.utcnow():
        raise HTTPException(status_code=401, detail="Refresh token expired")

    access_token = create_access_token(str(sess.user_id))
    return TokenOut(access_token=access_token)

@router.post("/logout")
def logout(
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    raw = request.cookies.get("refresh_token")
    if raw:
        token_h = hash_token(raw)
        sess = db.query(RefreshSession).filter(RefreshSession.refresh_token_hash == token_h).first()
        if sess and sess.revoked_at is None:
            sess.revoked_at = datetime.utcnow()
            db.commit()

    clear_refresh_cookie(response)
    log_activity(
        db,
        user_id=current_user.id if current_user else None,
        action="auth.logout",
        detail={"username": current_user.username} if current_user else None,
    )
    return {"message": "Logged out"}

@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.post("/change-password")
def change_password(payload: ChangePasswordIn, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Change password for the current authenticated user."""
    
    # Verify current password
    if not verify_password(payload.old_password, current_user.password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    
    # Update to new password
    current_user.password = hash_password(payload.new_password)
    db.commit()
    
    # Log the activity
    log_activity(db, user_id=current_user.id, action="auth.change_password", detail={"username": current_user.username}, location=current_user.location)
    
    return {"message": "Password changed successfully"}

@router.get("/debug/token-info")
def debug_token_info(
    creds: HTTPAuthorizationCredentials = Depends(security),
):
    """Debug endpoint: inspect token claims without database lookup"""
    token = creds.credentials
    try:
        # Decode without verification first to see what's inside
        from jose import jwt as jose_jwt
        unverified = jose_jwt.get_unverified_claims(token)
        
        # Now decode with verification
        from auth import decode_token as verify_and_decode
        sub = verify_and_decode(token)
        
        now = int(datetime.now(timezone.utc).timestamp())
        exp = unverified.get("exp")
        iat = unverified.get("iat")
        exp_seconds_remaining = (exp - now) if exp else None
        token_age_seconds = (now - iat) if iat else None
        
        return {
            "valid": True,
            "sub": sub,
            "iat": iat,
            "exp": exp,
            "now": now,
            "token_age_seconds": token_age_seconds,
            "exp_seconds_remaining": exp_seconds_remaining,
            "exp_days_remaining": round((exp_seconds_remaining or 0) / (24 * 3600), 2) if exp_seconds_remaining else None,
            "message": "Token is valid",
        }
    except Exception as e:
        return {
            "valid": False,
            "error": str(e),
            "message": "Token validation failed",
        }

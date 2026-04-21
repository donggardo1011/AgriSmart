from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
import secrets
import hashlib
from config import REFRESH_EXPIRES_DAYS

from config import JWT_SECRET, JWT_ALGORITHM, JWT_EXPIRES_MINUTES

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(subject: str) -> str:
    now = datetime.now(timezone.utc)
    exp = now + timedelta(minutes=JWT_EXPIRES_MINUTES)
    payload = {"sub": subject, "iat": int(now.timestamp()), "exp": int(exp.timestamp())}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def decode_token(token: str) -> str:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        sub = payload.get("sub")
        if not sub:
            raise ValueError("Token missing subject")
        
        # Additional explicit expiration check for debugging
        exp = payload.get("exp")
        iat = payload.get("iat")
        if exp:
            now = int(datetime.now(timezone.utc).timestamp())
            if now > exp:
                # Token has expired
                raise ValueError(f"Token expired. now={now}, exp={exp}, diff={now - exp}s")
        
        return sub
    except JWTError as e:
        raise ValueError(f"Invalid token: {str(e)}") from e
    except Exception as e:
        raise ValueError(f"Token decode error: {str(e)}") from e

# ---- Password reset token helpers ----
def generate_reset_token() -> str:
    # raw token sent to user
    return secrets.token_urlsafe(32)

def hash_token(raw_token: str) -> str:
    # store only a hash in DB
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()

def generate_refresh_token() -> str:
    # raw token sent to client (cookie)
    return secrets.token_urlsafe(48)

def refresh_expires_at() -> datetime:
    return datetime.now(timezone.utc) + timedelta(days=REFRESH_EXPIRES_DAYS)

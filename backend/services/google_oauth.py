from google.oauth2 import id_token
from google.auth.transport import requests
from config import GOOGLE_CLIENT_ID

class GoogleAuthError(Exception):
    pass

def verify_google_id_token(token: str) -> dict:
    if not GOOGLE_CLIENT_ID:
        raise GoogleAuthError("Missing GOOGLE_CLIENT_ID in .env")

    try:
        idinfo = id_token.verify_oauth2_token(token, requests.Request(), GOOGLE_CLIENT_ID)
        # idinfo fields commonly include: sub, email, email_verified, name, picture
        return idinfo
    except Exception as e:
        raise GoogleAuthError("Invalid Google id_token") from e
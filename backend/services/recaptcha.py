import httpx
from config import RECAPTCHA_SECRET

class RecaptchaError(Exception):
    pass

async def verify_recaptcha(token: str, remoteip: str | None = None) -> None:
    # DEV MODE: skip verification
    return
    if not RECAPTCHA_SECRET:
        raise RecaptchaError("Missing RECAPTCHA_SECRET in .env")

    data = {"secret": RECAPTCHA_SECRET, "response": token}
    if remoteip:
        data["remoteip"] = remoteip

    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.post("https://www.google.com/recaptcha/api/siteverify", data=data)
        r.raise_for_status()
        payload = r.json()

    if not payload.get("success"):
        # optional: payload may include 'error-codes'
        raise RecaptchaError("reCAPTCHA verification failed")
    

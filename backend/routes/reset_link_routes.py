from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["ResetLink"])

@router.get("/r/reset-password", response_class=HTMLResponse)
def reset_password_redirect(token: str):
    deep_link = f"agrismartech://reset-password?token={token}"

    # Simple HTML that tries to open the app
    return f"""
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>Open Agrismartech</title>
      </head>
      <body style="font-family: Arial; padding: 24px;">
        <h2>Reset Password</h2>
        <p>Opening Agrismartech app...</p>

        <p>If it doesn’t open automatically, tap:</p>
        <a href="{deep_link}" style="display:inline-block;padding:12px 16px;background:#22A45D;color:#fff;border-radius:8px;text-decoration:none;">
          Open Agrismartech App
        </a>

        <script>
          // Try to auto-open the deep link
          window.location.href = "{deep_link}";
        </script>
      </body>
    </html>
    """
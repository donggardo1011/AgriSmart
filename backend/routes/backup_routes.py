from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
import os
from routes.auth_routes import get_current_user
from models import User

router = APIRouter(prefix="/admin/backup", tags=["Admin Backup"])

# Path to the database file
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "users.db")

def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if (current_user.role or "user") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user

@router.get("/db")
async def download_db_backup(current_user: User = Depends(require_admin)):
    """
    Securely download the current SQLite database file as a snapshot.
    """
    if not os.path.exists(DB_PATH):
        raise HTTPException(status_code=404, detail="Database file not found")
    
    return FileResponse(
        path=DB_PATH,
        filename=f"rldd_backup_{os.path.basename(DB_PATH)}",
        media_type="application/x-sqlite3"
    )

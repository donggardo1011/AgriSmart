from __future__ import annotations

from datetime import datetime
import json
from typing import Any

from sqlalchemy.orm import Session

from models import ActivityLog


def log_activity(db: Session, *, user_id: int | None, action: str, detail: Any | None = None, location: str | None = None) -> None:
    try:
        payload: str | None
        if detail is None:
            payload = None
        elif isinstance(detail, str):
            payload = detail
        else:
            payload = json.dumps(detail, ensure_ascii=False)

        db.add(
            ActivityLog(
                user_id=user_id,
                action=action,
                detail=payload,
                location=location,
                created_at=datetime.utcnow(),
            )
        )
        db.commit()
    except Exception:
        # Logging must never break the main request.
        try:
            db.rollback()
        except Exception:
            pass


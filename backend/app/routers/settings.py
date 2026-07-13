from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.config import settings as env_settings
from app.db import get_db
from app.models import AppSettings
from app.schemas import AppSettingsRead, AppSettingsUpdate

router = APIRouter(prefix="/api/settings", tags=["settings"])


def get_app_settings(db: Session) -> AppSettings:
    """Runtime-editable settings, seeded from config.py's env-var default the
    first time they're read so an existing EXPIRING_SOON_DAYS override still
    applies until someone changes it via the API."""
    row = db.get(AppSettings, 1)
    if row is None:
        row = AppSettings(id=1, expiring_soon_days=env_settings.expiring_soon_days)
        db.add(row)
        db.commit()
        db.refresh(row)
    return row


@router.get("", response_model=AppSettingsRead)
def read_settings(db: Session = Depends(get_db)):
    return get_app_settings(db)


@router.patch("", response_model=AppSettingsRead)
def update_settings(payload: AppSettingsUpdate, db: Session = Depends(get_db)):
    row = get_app_settings(db)
    row.expiring_soon_days = payload.expiring_soon_days
    db.commit()
    db.refresh(row)
    return row

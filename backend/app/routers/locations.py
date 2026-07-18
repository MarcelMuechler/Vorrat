from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Location, Product, StockEntry
from app.schemas import LocationCreate, LocationRead, LocationUpdate

router = APIRouter(prefix="/api/locations", tags=["locations"])


def _find_by_name_ci(db: Session, name: str) -> Location | None:
    """SQLite's default unique constraint is case-sensitive, but the
    frontend's autocomplete matches case-insensitively -- without this check
    two clients (or one with a stale location list) racing "Fridge" and
    "fridge" would both pass the DB constraint and create duplicates."""
    return db.query(Location).filter(func.lower(Location.name) == name.lower()).first()


@router.get("", response_model=list[LocationRead])
def list_locations(db: Session = Depends(get_db)):
    return db.query(Location).order_by(Location.name).all()


@router.post("", response_model=LocationRead, status_code=201)
def create_location(payload: LocationCreate, db: Session = Depends(get_db)):
    if _find_by_name_ci(db, payload.name):
        raise HTTPException(409, "A location with that name already exists")
    location = Location(name=payload.name)
    db.add(location)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A location with that name already exists")
    db.refresh(location)
    return location


@router.patch("/{location_id}", response_model=LocationRead)
def update_location(location_id: int, payload: LocationUpdate, db: Session = Depends(get_db)):
    location = db.get(Location, location_id)
    if not location:
        raise HTTPException(404, "Location not found")
    existing = _find_by_name_ci(db, payload.name)
    if existing and existing.id != location_id:
        raise HTTPException(409, "A location with that name already exists")
    location.name = payload.name
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A location with that name already exists")
    db.refresh(location)
    return location


@router.delete("/{location_id}", status_code=204)
def delete_location(location_id: int, db: Session = Depends(get_db)):
    location = db.get(Location, location_id)
    if not location:
        raise HTTPException(404, "Location not found")
    has_stock = db.query(StockEntry).filter(StockEntry.location_id == location_id).first()
    if has_stock:
        raise HTTPException(409, "Location still has stock entries; move or remove them first")
    is_default_for_product = (
        db.query(Product).filter(Product.default_location_id == location_id).first()
    )
    if is_default_for_product:
        raise HTTPException(409, "Location is a product's default location; change that first")
    db.delete(location)
    db.commit()

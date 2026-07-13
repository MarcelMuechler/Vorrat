from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, contains_eager, joinedload

from app.db import get_db
from app.models import Location, Product, StockEntry
from app.routers.settings import get_app_settings
from app.schemas import (
    StockEntryConsume,
    StockEntryCreate,
    StockEntryRead,
    StockEntryUpdate,
    StockOverviewItem,
)
from app.utils import escape_like

router = APIRouter(prefix="/api/stock", tags=["stock"])


def _status(best_before_date: date | None, expiring_soon_days: int) -> str:
    if best_before_date is None:
        return "ok"
    today = date.today()
    if best_before_date < today:
        return "expired"
    if best_before_date <= today + timedelta(days=expiring_soon_days):
        return "expiring_soon"
    return "ok"


@router.get("", response_model=list[StockOverviewItem])
def list_stock(
    location_id: int | None = None,
    search: str | None = None,
    expiring_within_days: int | None = None,
    db: Session = Depends(get_db),
):
    # join(Product) is already needed for filtering; contains_eager reuses
    # that same join to populate entry.product instead of lazy-loading it
    # per row. joinedload(location) avoids the same N+1 for the nullable side.
    query = (
        db.query(StockEntry)
        .join(Product)
        .options(contains_eager(StockEntry.product), joinedload(StockEntry.location))
    )
    if location_id is not None:
        query = query.filter(StockEntry.location_id == location_id)
    if search:
        query = query.filter(Product.name.ilike(f"%{escape_like(search)}%", escape="\\"))
    if expiring_within_days is not None:
        cutoff = date.today() + timedelta(days=expiring_within_days)
        query = query.filter(
            StockEntry.best_before_date.isnot(None), StockEntry.best_before_date <= cutoff
        )

    expiring_soon_days = get_app_settings(db).expiring_soon_days
    items = []
    for entry in query.order_by(StockEntry.best_before_date.asc().nullslast()).all():
        items.append(
            StockOverviewItem(
                **StockEntryRead.model_validate(entry).model_dump(),
                product_name=entry.product.name,
                product_barcode=entry.product.barcode,
                location_name=entry.location.name if entry.location else None,
                status=_status(entry.best_before_date, expiring_soon_days),
            )
        )
    return items


@router.post("", response_model=StockEntryRead, status_code=201)
def add_stock(payload: StockEntryCreate, db: Session = Depends(get_db)):
    if not db.get(Product, payload.product_id):
        raise HTTPException(404, "Product not found")
    if payload.location_id is not None and not db.get(Location, payload.location_id):
        raise HTTPException(404, "Location not found")
    entry = StockEntry(**payload.model_dump())
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry


@router.patch("/{entry_id}", response_model=StockEntryRead)
def update_stock(entry_id: int, payload: StockEntryUpdate, db: Session = Depends(get_db)):
    entry = db.get(StockEntry, entry_id)
    if not entry:
        raise HTTPException(404, "Stock entry not found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(entry, key, value)
    db.commit()
    db.refresh(entry)
    return entry


@router.post("/{entry_id}/consume", response_model=StockEntryRead | None)
def consume_stock(entry_id: int, payload: StockEntryConsume, db: Session = Depends(get_db)):
    entry = db.get(StockEntry, entry_id)
    if not entry:
        raise HTTPException(404, "Stock entry not found")
    entry.amount -= payload.amount
    if entry.amount <= 0:
        db.delete(entry)
        db.commit()
        return None
    db.commit()
    db.refresh(entry)
    return entry


@router.delete("/{entry_id}", status_code=204)
def delete_stock(entry_id: int, db: Session = Depends(get_db)):
    entry = db.get(StockEntry, entry_id)
    if not entry:
        raise HTTPException(404, "Stock entry not found")
    db.delete(entry)
    db.commit()

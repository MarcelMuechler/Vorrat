import csv
import io
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session, contains_eager, joinedload

from app.db import get_db
from app.models import ConsumptionLog, Location, Product, StockEntry
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


def _effective_expiry(
    best_before_date: date | None, opened_at: date | None, open_shelf_life_days: int | None
) -> date | None:
    opened_expiry = opened_at + timedelta(days=open_shelf_life_days) if opened_at and open_shelf_life_days else None
    candidates = [d for d in (best_before_date, opened_expiry) if d is not None]
    return min(candidates) if candidates else None


def _status(expiry: date | None, expiring_soon_days: int) -> str:
    if expiry is None:
        return "ok"
    today = date.today()
    if expiry < today:
        return "expired"
    if expiry <= today + timedelta(days=expiring_soon_days):
        return "expiring_soon"
    return "ok"


def _query_stock(
    db: Session,
    location_id: int | None = None,
    product_id: int | None = None,
    search: str | None = None,
    expiring_within_days: int | None = None,
    category_id: int | None = None,
) -> list[StockOverviewItem]:
    # join(Product) is already needed for filtering; contains_eager reuses
    # that same join to populate entry.product instead of lazy-loading it
    # per row. joinedload(location) avoids the same N+1 for the nullable side.
    query = (
        db.query(StockEntry)
        .join(Product)
        .options(
            contains_eager(StockEntry.product).joinedload(Product.category),
            joinedload(StockEntry.location),
        )
    )
    if location_id is not None:
        query = query.filter(StockEntry.location_id == location_id)
    if product_id is not None:
        query = query.filter(StockEntry.product_id == product_id)
    if search:
        query = query.filter(Product.name.ilike(f"%{escape_like(search)}%", escape="\\"))
    if expiring_within_days is not None:
        cutoff = date.today() + timedelta(days=expiring_within_days)
        query = query.filter(
            StockEntry.best_before_date.isnot(None), StockEntry.best_before_date <= cutoff
        )
    if category_id is not None:
        query = query.filter(Product.category_id == category_id)

    expiring_soon_days = get_app_settings(db).expiring_soon_days
    items = []
    for entry in query.order_by(StockEntry.best_before_date.asc().nullslast()).all():
        items.append(
            StockOverviewItem(
                **StockEntryRead.model_validate(entry).model_dump(),
                product_name=entry.product.name,
                product_barcode=entry.product.barcode,
                product_category=entry.product.category_name,
                product_low_stock_threshold=entry.product.low_stock_threshold,
                location_name=entry.location.name if entry.location else None,
                status=_status(
                    _effective_expiry(
                        entry.best_before_date, entry.opened_at, entry.product.default_open_shelf_life_days
                    ),
                    expiring_soon_days,
                ),
            )
        )
    return items


@router.get("", response_model=list[StockOverviewItem])
def list_stock(
    location_id: int | None = None,
    product_id: int | None = None,
    search: str | None = None,
    expiring_within_days: int | None = None,
    category_id: int | None = None,
    db: Session = Depends(get_db),
):
    return _query_stock(db, location_id, product_id, search, expiring_within_days, category_id)


@router.get("/export.csv")
def export_stock_csv(db: Session = Depends(get_db)):
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        ["product_name", "barcode", "location", "amount", "best_before_date", "status"]
    )
    for item in _query_stock(db):
        writer.writerow(
            [
                item.product_name,
                item.product_barcode or "",
                item.location_name or "",
                item.amount,
                item.best_before_date or "",
                item.status,
            ]
        )
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=stock.csv"},
    )


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
    db.add(
        ConsumptionLog(product_id=entry.product_id, amount=payload.amount, reason=payload.reason)
    )
    # Repeated float subtraction (e.g. ten 0.1 consumes) can leave a tiny
    # non-zero residue instead of an exact 0, so treat anything below this
    # epsilon as fully consumed rather than leaving a ghost entry behind.
    if entry.amount <= 1e-9:
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
    # Removed without going through consume -- there's no "used" amount to
    # attribute, so this counts as spoiled/discarded for the waste summary.
    db.add(ConsumptionLog(product_id=entry.product_id, amount=entry.amount, reason="spoiled"))
    db.delete(entry)
    db.commit()

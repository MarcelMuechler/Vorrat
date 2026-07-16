from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.db import get_db
from app.models import Product, StockEntry
from app.routers.settings import get_app_settings
from app.routers.stock import _effective_expiry, _status
from app.schemas import StatsRead

router = APIRouter(prefix="/api/stats", tags=["stats"])


def low_stock_products_query(db: Session):
    """Products with a threshold set whose total amount across all stock
    entries (0 if it has none) is at or below that threshold -- same
    semantics as ProductGroup.isLowStock on the frontend. Shared with
    shopping_list.py's add-low-stock endpoint so the two definitions of
    "low stock" can't drift apart; callers do their own .all()/.count()."""
    return (
        db.query(Product)
        .outerjoin(StockEntry, StockEntry.product_id == Product.id)
        .filter(Product.low_stock_threshold.isnot(None))
        .group_by(Product.id)
        .having(func.coalesce(func.sum(StockEntry.amount), 0) <= Product.low_stock_threshold)
    )


@router.get("", response_model=StatsRead)
def get_stats(db: Session = Depends(get_db)):
    """Summary counters for Home Assistant REST sensors (#35) -- deliberately
    just a handful of plain SELECTs, no caching. Expiry status reuses
    stock.py's _status/_effective_expiry so the "expired"/"expiring_soon"
    definitions can never drift between the stock list and this endpoint."""
    expiring_soon_days = get_app_settings(db).expiring_soon_days

    total_products = db.query(Product).count()
    total_stock_entries = db.query(StockEntry).count()

    expired = 0
    expiring_soon = 0
    earliest_expiry: date | None = None
    entries = db.query(StockEntry).options(joinedload(StockEntry.product))
    for entry in entries:
        expiry = _effective_expiry(
            entry.best_before_date, entry.opened_at, entry.product.default_open_shelf_life_days
        )
        status = _status(expiry, expiring_soon_days)
        if status == "expired":
            expired += 1
        elif status == "expiring_soon":
            expiring_soon += 1
        if expiry is not None and (earliest_expiry is None or expiry < earliest_expiry):
            earliest_expiry = expiry

    low_stock_products = low_stock_products_query(db).count()

    # Entries with no price are simply skipped (not treated as free) --
    # func.sum ignores NULLs the same way SQL aggregates always do, but
    # amount * NULL is itself NULL, so filtering price.isnot(None) first
    # (rather than relying on the sum alone) is what actually keeps this a
    # true "sum of what's priced" instead of every row needing a price.
    total_value = (
        db.query(func.sum(StockEntry.amount * StockEntry.price))
        .filter(StockEntry.price.isnot(None))
        .scalar()
    ) or 0.0

    return StatsRead(
        total_products=total_products,
        total_stock_entries=total_stock_entries,
        expired=expired,
        expiring_soon=expiring_soon,
        low_stock_products=low_stock_products,
        earliest_expiry=earliest_expiry,
        total_value=total_value,
    )

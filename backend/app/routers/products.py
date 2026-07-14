from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload

from app.db import get_db
from app.models import ConsumptionLog, Product, StockEntry
from app.off_client import lookup_off
from app.schemas import ProductCreate, ProductRead, ProductUpdate
from app.utils import escape_like, normalize_barcode

router = APIRouter(prefix="/api/products", tags=["products"])


@router.get("", response_model=list[ProductRead])
def list_products(
    search: str | None = None,
    barcode: str | None = None,
    limit: int | None = Query(None, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    query = db.query(Product).options(joinedload(Product.category))
    if barcode:
        query = query.filter(Product.barcode == normalize_barcode(barcode))
    if search:
        query = query.filter(Product.name.ilike(f"%{escape_like(search)}%", escape="\\"))
    # Product.name isn't unique, so order by id as a tiebreaker to keep
    # pagination stable across pages when multiple products share a name.
    query = query.order_by(Product.name, Product.id).offset(offset)
    if limit is not None:
        query = query.limit(limit)
    return query.all()


@router.get("/{product_id}", response_model=ProductRead)
def get_product(product_id: int, db: Session = Depends(get_db)):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    return product


@router.post("", response_model=ProductRead, status_code=201)
def create_product(payload: ProductCreate, db: Session = Depends(get_db)):
    product = Product(**payload.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.patch("/{product_id}", response_model=ProductRead)
def update_product(product_id: int, payload: ProductUpdate, db: Session = Depends(get_db)):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(product, key, value)
    db.commit()
    db.refresh(product)
    return product


@router.post("/{product_id}/refresh-from-off")
async def refresh_product_from_off(product_id: int, db: Session = Depends(get_db)):
    """Re-fetches this product's Open Food Facts listing (bypassing the
    local-DB-first check /api/barcode/{code} does, which would otherwise just
    hand back the same stale local record) so the caller can review and
    apply any changes via the existing PATCH endpoint. Doesn't write
    anything itself."""
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    if not product.barcode:
        raise HTTPException(409, "Product has no barcode to look up")
    off_product = await lookup_off(product.barcode)
    if not off_product:
        raise HTTPException(404, "Not found on Open Food Facts")
    return off_product


@router.delete("/{product_id}", status_code=204)
def delete_product(product_id: int, db: Session = Depends(get_db)):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    has_stock = db.query(StockEntry).filter(StockEntry.product_id == product_id).first()
    if has_stock:
        raise HTTPException(409, "Product still has stock entries; remove them first")
    # ConsumptionLog rows reference this product too, but unlike StockEntry
    # above we don't block the delete on them -- with PRAGMA foreign_keys=ON
    # (db.py) a leftover row would otherwise turn this into a raw
    # IntegrityError. Deliberately bulk-delete them instead: waste history
    # for a product that no longer exists isn't meaningful to keep around.
    db.query(ConsumptionLog).filter(ConsumptionLog.product_id == product_id).delete()
    db.delete(product)
    db.commit()

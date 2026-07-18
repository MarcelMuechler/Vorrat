import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload, selectinload

from app.config import settings
from app.db import get_db
from app.models import (
    Category,
    ConsumptionLog,
    Location,
    Product,
    ProductBarcode,
    ShoppingListItem,
    StockEntry,
)
from app.off_client import lookup_off
from app.schemas import ProductBarcodeCreate, ProductCreate, ProductRead, ProductUpdate
from app.utils import escape_like, normalize_barcode

router = APIRouter(prefix="/api/products", tags=["products"])

# Mirrors main.py's UPLOADS_DIR (which mounts this same directory at
# /uploads) -- computed independently here rather than imported from main.py
# to avoid a circular import (main.py imports this router).
UPLOADS_DIR = Path(settings.uploads_dir)
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

# Whitelist, not a blocklist: an uploaded product photo has no legitimate
# reason to be anything but one of these, and content-type is client-supplied
# so this is the actual security boundary, not just UX.
_ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}
_MAX_IMAGE_BYTES = 10 * 1024 * 1024


@router.get("", response_model=list[ProductRead])
def list_products(
    search: str | None = None,
    barcode: str | None = None,
    limit: int | None = Query(None, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    query = db.query(Product).options(joinedload(Product.category), selectinload(Product.barcodes))
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


def _validate_product_references(db: Session, category_id: int | None, default_location_id: int | None) -> None:
    """Mirrors add_stock's product_id/location_id validation in stock.py: a
    bad FK should come back as a clean 404, not fall through to SQLite and
    surface as a raw 500 (SQLite's own FK enforcement, turned on in db.py,
    would otherwise be the only thing catching this)."""
    if category_id is not None and not db.get(Category, category_id):
        raise HTTPException(404, "Category not found")
    if default_location_id is not None and not db.get(Location, default_location_id):
        raise HTTPException(404, "Location not found")


def _barcode_in_use(db: Session, code: str, exclude_product_id: int | None = None) -> bool:
    """True if `code` already exists anywhere in the single global barcode
    namespace (#223) -- as any product's primary `Product.barcode` or any
    product's alternate `ProductBarcode.code`. The two tables have their own
    per-table unique constraints but nothing spanning them, so without this
    the same code could be one product's primary and another's alternate;
    since barcode.py's lookup checks primary codes first, the alternate would
    be silently shadowed and scans would resolve to the wrong product.

    `exclude_product_id` skips a product's own rows so a no-op re-save of an
    unchanged barcode doesn't collide with itself. This is a pragmatic
    application-level guard; each write still commits under a try/except
    IntegrityError to stay race-safe as far as the per-table constraints
    permit (a single-table rework would be a large migration for little gain
    on a self-hosted, single-user app)."""
    primary_q = db.query(Product.id).filter(Product.barcode == code)
    alt_q = db.query(ProductBarcode.id).filter(ProductBarcode.code == code)
    if exclude_product_id is not None:
        primary_q = primary_q.filter(Product.id != exclude_product_id)
        alt_q = alt_q.filter(ProductBarcode.product_id != exclude_product_id)
    return db.query(primary_q.exists()).scalar() or db.query(alt_q.exists()).scalar()


@router.post("", response_model=ProductRead, status_code=201)
def create_product(payload: ProductCreate, db: Session = Depends(get_db)):
    _validate_product_references(db, payload.category_id, payload.default_location_id)
    if payload.barcode is not None and _barcode_in_use(db, payload.barcode):
        raise HTTPException(409, "A product with this barcode already exists")
    product = Product(**payload.model_dump())
    db.add(product)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A product with this barcode already exists")
    db.refresh(product)
    return product


@router.patch("/{product_id}", response_model=ProductRead)
def update_product(product_id: int, payload: ProductUpdate, db: Session = Depends(get_db)):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    updates = payload.model_dump(exclude_unset=True)
    _validate_product_references(db, updates.get("category_id"), updates.get("default_location_id"))
    if "barcode" in updates and updates["barcode"] is not None and _barcode_in_use(
        db, updates["barcode"], exclude_product_id=product_id
    ):
        raise HTTPException(409, "A product with this barcode already exists")
    for key, value in updates.items():
        setattr(product, key, value)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A product with this barcode already exists")
    db.refresh(product)
    return product


@router.post("/{product_id}/image", response_model=ProductRead)
async def upload_product_image(
    product_id: int, file: UploadFile = File(...), db: Session = Depends(get_db)
):
    """Lets a product get a photo without a barcode match on Open Food Facts
    (#210) -- previously image_url was only ever set by pasting a URL or by
    the OFF lookup in barcode.py. Saves under a filename derived from the
    product id and a random suffix (never the client-supplied filename, which
    is untrusted input) so re-uploads can't collide and don't overwrite a
    still-referenced old file before the DB row is updated."""
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    ext = _ALLOWED_IMAGE_TYPES.get(file.content_type)
    if ext is None:
        raise HTTPException(415, "Unsupported image type")
    contents = await file.read()
    if not contents:
        raise HTTPException(422, "Empty file")
    if len(contents) > _MAX_IMAGE_BYTES:
        raise HTTPException(413, "Image too large")
    filename = f"{product_id}-{uuid.uuid4().hex[:12]}{ext}"
    (UPLOADS_DIR / filename).write_bytes(contents)
    # A previous upload for this product, if any, is now unreferenced --
    # clean it up so repeated re-uploads don't silently accumulate orphaned
    # files on disk. Only ever removes files inside UPLOADS_DIR (never a
    # pasted external image_url), and only after the new file is safely
    # written.
    old_url = product.image_url
    # Leading slash to match how every other path elsewhere in this codebase
    # is written (e.g. ApiClient._uri's '/api/...' call sites) -- the
    # frontend's own base-relative resolution strips it before use, the same
    # way it does for API paths, so this stays correct under HA Ingress.
    product.image_url = f"/uploads/{filename}"
    db.commit()
    if old_url and old_url.startswith("/uploads/"):
        (UPLOADS_DIR / old_url.removeprefix("/uploads/")).unlink(missing_ok=True)
    db.refresh(product)
    return product


@router.post("/{product_id}/barcodes", response_model=ProductRead, status_code=201)
def add_product_barcode(product_id: int, payload: ProductBarcodeCreate, db: Session = Depends(get_db)):
    """Adds an alternate/extra scannable code for this product (#208) --
    e.g. a different pack size or a regional/reprinted barcode -- so
    /api/barcode/{code} resolves it to this same product instead of falling
    through to the Open Food Facts "create a new product" flow."""
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    # Barcodes are one global namespace (#223): reject a code already claimed
    # by any product's primary barcode (including this product's own) or any
    # other product's alternate code, so /api/barcode/{code} can never resolve
    # to the wrong product.
    if _barcode_in_use(db, payload.code):
        raise HTTPException(409, "A product with this barcode already exists")
    db.add(ProductBarcode(product_id=product_id, code=payload.code))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A product with this barcode already exists")
    db.refresh(product)
    return product


@router.delete("/{product_id}/barcodes/{code}", response_model=ProductRead)
def remove_product_barcode(product_id: int, code: str, db: Session = Depends(get_db)):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    code = normalize_barcode(code) or code
    barcode_row = (
        db.query(ProductBarcode)
        .filter(ProductBarcode.product_id == product_id, ProductBarcode.code == code)
        .first()
    )
    if not barcode_row:
        raise HTTPException(404, "Barcode not found for this product")
    db.delete(barcode_row)
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
    # ShoppingListItem rows reference this product too. Unlike StockEntry
    # above, we don't block the delete on them -- a shopping-list item is a
    # to-buy intent, not a physical stock record, and the model already has
    # a free-text fallback (name/unit, resolved by shopping_list.py's
    # _display_name/_display_unit when product_id is null) for exactly this
    # case. So instead of blocking or losing the entry to an IntegrityError
    # under PRAGMA foreign_keys=ON (db.py), snapshot the resolved name/unit
    # onto the item (if not already overridden) and detach product_id,
    # preserving it -- this covers both open and completed (done) items.
    shopping_items = (
        db.query(ShoppingListItem).filter(ShoppingListItem.product_id == product_id).all()
    )
    for item in shopping_items:
        if item.name is None:
            item.name = product.name
        if item.unit is None:
            item.unit = product.quantity_unit
        item.product_id = None
    # ConsumptionLog rows reference this product too, but unlike StockEntry
    # above we don't block the delete on them -- with PRAGMA foreign_keys=ON
    # (db.py) a leftover row would otherwise turn this into a raw
    # IntegrityError. Deliberately bulk-delete them instead: waste history
    # for a product that no longer exists isn't meaningful to keep around.
    db.query(ConsumptionLog).filter(ConsumptionLog.product_id == product_id).delete()
    image_url = product.image_url
    db.delete(product)
    db.commit()
    # Same cleanup as upload_product_image's re-upload path -- an uploaded
    # (not pasted-URL) photo has no other referrer once its product is gone.
    if image_url and image_url.startswith("/uploads/"):
        (UPLOADS_DIR / image_url.removeprefix("/uploads/")).unlink(missing_ok=True)

import ipaddress
import socket
import uuid
from pathlib import Path
from urllib.parse import urljoin, urlparse

import httpx
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
from app.off_client import OffLookupError, lookup_off
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
# Caps the manual redirect-following loop in _cache_remote_image -- generous
# enough for any legitimate CDN hop chain, but bounded so a malicious/broken
# host can't make this loop indefinitely.
_MAX_REDIRECTS = 5


class _UnsafeRedirectTargetError(Exception):
    """Raised by _assert_public_host when a URL's host resolves to a
    loopback/link-local/private address, so _cache_remote_image's caller can
    treat it exactly like any other fetch failure (network error, bad
    content-type, ...): drop the image, don't raise past this function."""


def _assert_public_host(url: str) -> None:
    """Resolves url's hostname to its IP address(es) and raises if any of
    them is loopback, link-local, or private (RFC1918/RFC4193 etc.) -- the
    SSRF guard for _cache_remote_image (#288). image_url is free-text (must
    accept both Open Food Facts' CDN and arbitrary pasted external URLs, see
    _delete_local_upload's comment), so without this a pasted/OFF-relayed URL
    could point this server's own outbound fetch at localhost, a LAN device,
    or a link-local metadata endpoint -- and since v1 has no auth and CORS is
    wide open, that's reachable via CSRF from any website.

    Checks the *resolved* IP, never just the hostname string, so a DNS name
    that resolves to an internal address (DNS rebinding) is caught the same
    way a literal internal IP or a name like 'localhost' is. Must be called
    again after every redirect hop, not just the initial URL -- otherwise
    httpx's follow_redirects would let a first hop to an innocuous public
    host redirect on to an internal target and bypass this entirely."""
    host = urlparse(url).hostname
    if not host:
        raise _UnsafeRedirectTargetError(f"URL has no host: {url}")
    try:
        resolved = socket.getaddrinfo(host, None)
    except socket.gaierror as exc:
        raise _UnsafeRedirectTargetError(f"DNS resolution failed for host: {host}") from exc
    for *_rest, sockaddr in resolved:
        ip = ipaddress.ip_address(sockaddr[0])
        if ip.is_private or ip.is_loopback or ip.is_link_local:
            raise _UnsafeRedirectTargetError(f"{host} resolves to a non-public address: {ip}")


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


def _cache_remote_image(url: str, product_id: int) -> str | None:
    """Downloads a third-party image_url (Open Food Facts' CDN, or a pasted
    external URL) and stores it under UPLOADS_DIR the same way
    upload_product_image does, so the frontend only ever renders a local
    /uploads/... path and never hotlinks a third party on every stock-overview
    load (#262). Best-effort like off_client's lookups: any failure (network,
    timeout, bad content-type, oversized) just drops the image rather than
    falling back to the original external URL -- a broken/slow external host
    shouldn't be able to fail a product save.

    Streams the response and aborts as soon as _MAX_IMAGE_BYTES is exceeded,
    rather than buffering the whole body first -- a malicious/misbehaving
    external host can't use an unbounded Content-Length to force this process
    to hold an arbitrarily large response in memory.

    Follows redirects manually (follow_redirects=False, up to _MAX_REDIRECTS
    hops) instead of handing that off to httpx, re-running _assert_public_host
    on each hop's target -- an initial-URL-only host check would otherwise be
    bypassable by redirecting from an allowed host to an internal one (#288)."""
    try:
        current_url = url
        for _ in range(_MAX_REDIRECTS + 1):
            _assert_public_host(current_url)
            with httpx.stream("GET", current_url, timeout=5.0, follow_redirects=False) as response:
                if response.is_redirect:
                    location = response.headers.get("location")
                    if not location:
                        return None
                    current_url = urljoin(current_url, location)
                    continue
                response.raise_for_status()
                content_type = response.headers.get("content-type", "").split(";")[0].strip()
                ext = _ALLOWED_IMAGE_TYPES.get(content_type)
                if ext is None:
                    return None
                content = bytearray()
                for chunk in response.iter_bytes():
                    content += chunk
                    if len(content) > _MAX_IMAGE_BYTES:
                        return None
            break
        else:
            # Exhausted _MAX_REDIRECTS hops without reaching a non-redirect
            # response -- treat like any other malformed/misbehaving host.
            return None
    except (httpx.HTTPError, _UnsafeRedirectTargetError):
        return None
    filename = f"{product_id}-{uuid.uuid4().hex[:12]}{ext}"
    (UPLOADS_DIR / filename).write_bytes(content)
    return f"/uploads/{filename}"


def _is_external_url(url: str | None) -> bool:
    return bool(url) and url.startswith(("http://", "https://"))


def _delete_local_upload(url: str | None) -> None:
    """Deletes a previously-saved /uploads/... file (a stale product photo
    being replaced or a deleted product's last reference), if any.

    Resolves the path and checks it's still inside UPLOADS_DIR before
    unlinking -- image_url is a free-text field (schemas.py places no format
    restriction on it, since it must also accept arbitrary pasted external
    URLs), so a value like "/uploads/../../vorrat.db" must not be able to
    walk this out of the uploads directory and delete an unrelated file."""
    if not url or not url.startswith("/uploads/"):
        return
    path = (UPLOADS_DIR / url.removeprefix("/uploads/")).resolve()
    if path.is_relative_to(UPLOADS_DIR.resolve()):
        path.unlink(missing_ok=True)


@router.post("", response_model=ProductRead, status_code=201)
def create_product(payload: ProductCreate, db: Session = Depends(get_db)):
    _validate_product_references(db, payload.category_id, payload.default_location_id)
    if payload.barcode is not None and _barcode_in_use(db, payload.barcode):
        raise HTTPException(409, "A product with this barcode already exists")
    product = Product(**payload.model_dump())
    db.add(product)
    try:
        db.flush()  # assigns product.id (needed for the cached filename) without committing yet
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A product with this barcode already exists")
    if _is_external_url(product.image_url):
        product.image_url = _cache_remote_image(product.image_url, product.id)
    db.commit()
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
    old_image_url = product.image_url
    for key, value in updates.items():
        setattr(product, key, value)
    if "image_url" in updates and _is_external_url(product.image_url):
        product.image_url = _cache_remote_image(product.image_url, product_id)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A product with this barcode already exists")
    db.refresh(product)
    # A previous locally-uploaded/cached photo, if any, is now unreferenced
    # once image_url has actually changed -- same cleanup as
    # upload_product_image's re-upload path, just missing here until now
    # (silently orphaning a file on disk every time an image_url was pasted
    # or refreshed over an existing local upload).
    if "image_url" in updates and old_image_url != product.image_url:
        _delete_local_upload(old_image_url)
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
    _delete_local_upload(old_url)
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
    try:
        off_product = await lookup_off(product.barcode)
    except OffLookupError:
        # Same distinction barcode.py makes: OFF being unreachable is not the
        # same as a genuine "not found" and must not surface as one.
        raise HTTPException(503, {"source": "none", "reason": "off_unreachable"}) from None
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
    _delete_local_upload(image_url)

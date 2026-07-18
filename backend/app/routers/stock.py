import csv
import io
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import StreamingResponse
from sqlalchemy import func, update
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, contains_eager, joinedload

from app.db import get_db
from app.models import ConsumptionLog, Location, Product, StockEntry
from app.routers.settings import get_app_settings
from app.schemas import (
    BulkStockConsume,
    BulkStockConsumeResult,
    BulkStockDeleteResult,
    BulkStockEntryIds,
    BulkStockMove,
    BulkStockMoveResult,
    StockConsumeResult,
    StockEntryConsume,
    StockEntryCreate,
    StockEntryRead,
    StockEntryUpdate,
    StockImportResult,
    StockOverviewItem,
)
from app.utils import escape_like, normalize_barcode

router = APIRouter(prefix="/api/stock", tags=["stock"])


def _effective_expiry(
    best_before_date: date | None, opened_at: date | None, open_shelf_life_days: int | None
) -> date | None:
    opened_expiry = (
        opened_at + timedelta(days=open_shelf_life_days)
        if opened_at is not None and open_shelf_life_days is not None
        else None
    )
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
    limit: int | None = None,
    offset: int = 0,
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
    # id is a tiebreaker so pagination stays stable across pages when
    # multiple entries share the same best_before_date (or are all null).
    # The joins above (Product, Location) are both to-one from StockEntry's
    # side, so they never multiply rows -- OFFSET/LIMIT on this query paginate
    # stock entries correctly without needing a subquery-on-ids workaround.
    query = query.order_by(StockEntry.best_before_date.asc().nullslast(), StockEntry.id).offset(offset)
    if limit is not None:
        query = query.limit(limit)
    items = []
    for entry in query.all():
        items.append(
            StockOverviewItem(
                **StockEntryRead.model_validate(entry).model_dump(),
                product_name=entry.product.name,
                product_barcode=entry.product.barcode,
                product_category=entry.product.category_name,
                product_low_stock_threshold=entry.product.low_stock_threshold,
                product_quantity_unit=entry.product.quantity_unit,
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
    limit: int | None = Query(None, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    return _query_stock(
        db, location_id, product_id, search, expiring_within_days, category_id, limit, offset
    )


@router.get("/export.csv")
def export_stock_csv(db: Session = Depends(get_db)):
    """Exports every stock entry as one CSV row. Preserves the StockEntry
    fields that affect correctness on re-import -- purchased_date, opened_at
    (both feed _effective_expiry above, so dropping opened_at could silently
    turn an expired opened item into a non-expiring one after a round-trip)
    and price -- plus the owning product's quantity_unit for context. It
    does NOT export product defaults (default_best_before_days,
    default_open_shelf_life_days, low_stock_threshold, target_stock_level),
    categories, or images: those live on Product, not StockEntry, and
    round-tripping them through a stock file would mean silently rewriting
    shared product data every time someone edits a CSV. `status` is a
    derived, read-only column (kept for human review) and is ignored on
    import -- see import_stock_csv below for exactly what's read back."""
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "product_name",
            "barcode",
            "quantity_unit",
            "location",
            "amount",
            "best_before_date",
            "purchased_date",
            "opened_at",
            "price",
            "status",
        ]
    )
    for item in _query_stock(db):
        writer.writerow(
            [
                item.product_name,
                item.product_barcode or "",
                item.product_quantity_unit,
                item.location_name or "",
                item.amount,
                item.best_before_date or "",
                item.purchased_date or "",
                item.opened_at or "",
                item.price if item.price is not None else "",
                item.status,
            ]
        )
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=stock.csv"},
    )


def _resolve_location(db: Session, name: str, cache: dict[str, Location]) -> Location:
    key = name.lower()
    if key in cache:
        return cache[key]
    location = db.query(Location).filter(func.lower(Location.name) == key).first()
    if location is None:
        location = Location(name=name)
        db.add(location)
        db.flush()
    cache[key] = location
    return location


def _resolve_product(
    db: Session,
    name: str,
    barcode: str | None,
    cache: dict[str, Product],
    quantity_unit: str | None = None,
) -> Product:
    # quantity_unit is only ever applied to a brand-new Product -- an
    # existing match (by barcode or name) keeps whatever unit it already
    # has, since that unit is shared by every other stock entry for the
    # same product and a stock CSV re-import shouldn't silently redefine it.
    new_product_kwargs = {"quantity_unit": quantity_unit} if quantity_unit else {}

    # Barcode wins when present (it's the more precise match); a cache keyed
    # by barcode/name is required in addition to the DB lookup so that two
    # rows in the same import that both introduce the same new product don't
    # each try to INSERT it and collide on the unique barcode/violate intent.
    if barcode:
        key = f"barcode:{barcode}"
        if key in cache:
            return cache[key]
        product = db.query(Product).filter(Product.barcode == barcode).first()
        if product is None:
            product = Product(name=name, barcode=barcode, **new_product_kwargs)
            db.add(product)
            db.flush()
        cache[key] = product
        return product

    key = f"name:{name.lower()}"
    if key in cache:
        return cache[key]
    product = db.query(Product).filter(func.lower(Product.name) == name.lower()).first()
    if product is None:
        product = Product(name=name, **new_product_kwargs)
        db.add(product)
        db.flush()
    cache[key] = product
    return product


def _parse_optional_date(row: dict, column: str) -> date | None:
    raw = (row.get(column) or "").strip()
    if not raw:
        return None
    try:
        return date.fromisoformat(raw)
    except ValueError:
        raise ValueError(f"invalid {column}: {raw!r}") from None


# Keeps one oversized upload from being buffered whole in memory -- checked
# both against the (possibly absent or lying) Content-Length header up front
# and again while actually reading the body, see _read_capped_body. 5 MB
# comfortably covers even a large household's stock export/import.
IMPORT_CSV_MAX_BYTES = 5 * 1024 * 1024
# A pathological file could otherwise turn `errors` itself into an unbounded
# response body; cap how many bad rows we report back.
IMPORT_CSV_MAX_ERRORS = 200


async def _read_capped_body(request: Request, max_bytes: int) -> bytes:
    content_length = request.headers.get("content-length")
    if content_length is not None:
        try:
            claimed = int(content_length)
        except ValueError:
            claimed = None
        if claimed is not None and claimed > max_bytes:
            raise HTTPException(413, f"CSV upload exceeds the {max_bytes}-byte limit")

    chunks = []
    total = 0
    async for chunk in request.stream():
        total += len(chunk)
        if total > max_bytes:
            raise HTTPException(413, f"CSV upload exceeds the {max_bytes}-byte limit")
        chunks.append(chunk)
    return b"".join(chunks)


def _import_stock_csv_sync(db: Session, body: bytes) -> dict:
    """Does the actual parsing + row-by-row DB writes -- run off the event
    loop via run_in_threadpool by the route below, since a large CSV parsed
    and flushed synchronously here would otherwise stall unrelated requests.

    Every row is attempted independently: a bad row is recorded in `errors`
    (row numbers are 1-based over the data rows, i.e. excluding the header;
    capped at IMPORT_CSV_MAX_ERRORS) and does not stop the rest of the file
    from importing. A parse-level failure (bad encoding, malformed CSV) or a
    database error aborts the whole import and rolls back everything flushed
    so far -- partial imports would be worse than a clean failure that the
    caller can just retry."""
    try:
        text = body.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise HTTPException(400, f"CSV must be UTF-8 encoded: {exc}") from None

    location_cache: dict[str, Location] = {}
    product_cache: dict[str, Product] = {}
    imported = 0
    errors = []

    try:
        reader = csv.DictReader(io.StringIO(text))
        for row_number, row in enumerate(reader, start=1):
            try:
                name = (row.get("product_name") or "").strip()
                if not name:
                    raise ValueError("product_name is required")

                barcode = normalize_barcode(row.get("barcode"))

                amount_raw = (row.get("amount") or "").strip()
                if not amount_raw:
                    raise ValueError("amount is required")
                try:
                    amount = float(amount_raw)
                except ValueError:
                    raise ValueError(f"invalid amount: {amount_raw!r}") from None
                if amount <= 0:
                    raise ValueError(f"amount must be greater than 0: {amount_raw!r}")

                best_before_date = _parse_optional_date(row, "best_before_date")
                purchased_date = _parse_optional_date(row, "purchased_date")
                opened_at = _parse_optional_date(row, "opened_at")

                price_raw = (row.get("price") or "").strip()
                price = None
                if price_raw:
                    try:
                        price = float(price_raw)
                    except ValueError:
                        raise ValueError(f"invalid price: {price_raw!r}") from None
                    if price < 0:
                        raise ValueError(f"price must not be negative: {price_raw!r}")

                quantity_unit = (row.get("quantity_unit") or "").strip() or None

                location_raw = (row.get("location") or "").strip()
                location_id = None
                if location_raw:
                    location_id = _resolve_location(db, location_raw, location_cache).id

                product = _resolve_product(db, name, barcode, product_cache, quantity_unit)

                entry = StockEntry(
                    product_id=product.id,
                    location_id=location_id,
                    amount=amount,
                    best_before_date=best_before_date,
                    purchased_date=purchased_date,
                    opened_at=opened_at,
                    price=price,
                )
                db.add(entry)
                db.flush()
                imported += 1
            except ValueError as exc:
                if len(errors) < IMPORT_CSV_MAX_ERRORS:
                    errors.append({"row": row_number, "error": str(exc)})
    except csv.Error as exc:
        db.rollback()
        raise HTTPException(400, f"Malformed CSV: {exc}") from None
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(400, "Import failed due to a database error; no rows were committed") from None

    db.commit()
    return {"imported": imported, "errors": errors}


@router.post("/import.csv", response_model=StockImportResult)
async def import_stock_csv(request: Request, db: Session = Depends(get_db)):
    """Accepts the CSV as a raw request body (not multipart) -- the simplest
    shape for both `curl --data-binary @file.csv` and Flutter's `http.post`.
    Column shape matches export_stock_csv above so export -> import
    round-trips the fields that affect correctness (purchased_date,
    opened_at, price, quantity_unit); the trailing `status` column from the
    export is derived and simply ignored on the way back in. All of the new
    columns are optional and read via DictReader.get(), so a CSV from before
    they existed (or one missing them entirely) still imports fine --
    missing/blank values just come back as null, exactly like an old-format
    best_before_date-only file always has. quantity_unit is only applied
    when a row's product_name/barcode doesn't match an existing product
    (see _resolve_product) -- an existing product keeps its current unit
    rather than having it silently rewritten by a stock import.

    Limited to IMPORT_CSV_MAX_BYTES (5 MB) -- returns 413 if the upload is
    (or turns out to be) larger, checked both via Content-Length up front and
    while streaming the body itself. Parsing and DB writes run in a worker
    thread so a large-but-within-limit file doesn't block the event loop; any
    parse or database error rolls back the whole import cleanly (see
    _import_stock_csv_sync)."""
    body = await _read_capped_body(request, IMPORT_CSV_MAX_BYTES)
    return await run_in_threadpool(_import_stock_csv_sync, db, body)


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


def _consume_entry(
    db: Session, entry: StockEntry, amount: float, reason: str, undoable: bool = False
) -> tuple[bool, int]:
    """Logs the consumption and either shrinks or fully removes `entry`.
    Returns (fully_consumed, consumption_log_id): fully_consumed is True if
    the entry was fully consumed (deleted), False if it was only partially
    reduced and still exists; consumption_log_id is the id of the
    ConsumptionLog row just written, needed by callers that let this be
    undone later (#160). Caller is responsible for commit/refresh -- kept
    out of here so bulk callers can batch a single commit across many
    entries.

    `undoable` marks this consume as reversible by undo_consume (#224) and
    snapshots -- immutably, onto the log row -- exactly the StockEntry fields
    needed to reconstruct the removed portion later. Only a *single* consume
    passes True; bulk consume leaves it False so those rows can't be undone
    into arbitrary stock.

    Raises HTTPException(422) if `amount` exceeds what's actually left on
    `entry`. The decrement is a single atomic UPDATE whose WHERE clause folds
    in the "enough left" check (StockEntry.amount >= amount) rather than
    comparing entry.amount in Python and writing separately -- so two
    concurrent consumes racing on the same entry (e.g. both requesting 0.6 of
    a 1.0 entry) can't both read "enough left" and together log more than was
    ever there: SQLite serializes the two writes, the second one re-evaluates
    the WHERE clause against the first's already-committed result, and its
    UPDATE simply matches zero rows.
    """
    result = db.execute(
        update(StockEntry)
        .where(StockEntry.id == entry.id, StockEntry.amount >= amount)
        .values(amount=StockEntry.amount - amount)
    )
    if result.rowcount == 0:
        raise HTTPException(422, "Requested amount exceeds the entry's remaining stock")
    log = ConsumptionLog(
        product_id=entry.product_id,
        amount=amount,
        reason=reason,
        quantity_unit=entry.product.quantity_unit,
        # Snapshotted from the entry being consumed (not looked up live)
        # for the same reason as quantity_unit above -- see
        # ConsumptionLog.price's docstring in models.py.
        price=entry.price,
        # Immutable undo snapshot (#224) -- captured only for a single,
        # reversible consume. product_id/amount/price above already cover the
        # rest of what undo_consume needs to rebuild the removed portion.
        undoable=undoable,
        undo_location_id=entry.location_id if undoable else None,
        undo_best_before_date=entry.best_before_date if undoable else None,
        undo_purchased_date=entry.purchased_date if undoable else None,
        undo_opened_at=entry.opened_at if undoable else None,
    )
    db.add(log)
    # Flushed (not committed) so log.id is populated for the caller even
    # though the transaction isn't final yet -- mirrors _resolve_location/
    # _resolve_product's use of flush() above for the same reason.
    db.flush()
    # Re-read the amount the UPDATE above actually wrote (same transaction,
    # so this sees that uncommitted write) rather than trusting the
    # Python-side entry.amount, which may be stale.
    db.refresh(entry)
    # Repeated float subtraction (e.g. ten 0.1 consumes) can leave a tiny
    # non-zero residue instead of an exact 0, so treat anything below this
    # epsilon as fully consumed rather than leaving a ghost entry behind.
    if entry.amount <= 1e-9:
        db.delete(entry)
        return True, log.id
    return False, log.id


def _delete_entry(db: Session, entry: StockEntry) -> None:
    """Removes `entry` without going through consume -- there's no "used"
    amount to attribute, so this counts as spoiled/discarded for the waste
    summary. Caller is responsible for commit."""
    db.add(
        ConsumptionLog(
            product_id=entry.product_id,
            amount=entry.amount,
            reason="spoiled",
            quantity_unit=entry.product.quantity_unit,
            price=entry.price,
        )
    )
    db.delete(entry)


def _get_entries_or_404(db: Session, entry_ids: list[int]) -> list[StockEntry]:
    """Looks up entry_ids (de-duplicated, order preserved) and 404s naming
    every id that doesn't exist, before any mutation happens -- so a bulk
    request with even one bogus id changes nothing (all-or-nothing)."""
    unique_ids = list(dict.fromkeys(entry_ids))
    entries = db.query(StockEntry).filter(StockEntry.id.in_(unique_ids)).all()
    by_id = {entry.id: entry for entry in entries}
    missing = [i for i in unique_ids if i not in by_id]
    if missing:
        raise HTTPException(404, f"Stock entries not found: {missing}")
    return [by_id[i] for i in unique_ids]


# The three /bulk/* routes below must be registered before the /{entry_id}...
# routes further down: Starlette matches routes in registration order, and
# since entry_id has no ":int" constraint in the path string itself (only in
# the function signature, which FastAPI validates *after* the path already
# matched), "/{entry_id}/consume" would otherwise greedily match
# "/bulk/consume" too and fail with a 422 (can't parse "bulk" as int) instead
# of falling through to the route actually meant to handle it.
@router.post("/bulk/consume", response_model=BulkStockConsumeResult)
def bulk_consume_stock(payload: BulkStockConsume, db: Session = Depends(get_db)):
    """Fully consumes every listed entry (its whole remaining amount), each
    logged exactly like a single consume-to-zero would be."""
    entries = _get_entries_or_404(db, payload.entry_ids)
    for entry in entries:
        _consume_entry(db, entry, entry.amount, payload.reason)
    db.commit()
    return BulkStockConsumeResult(consumed=len(entries))


@router.post("/bulk/delete", response_model=BulkStockDeleteResult)
def bulk_delete_stock(payload: BulkStockEntryIds, db: Session = Depends(get_db)):
    entries = _get_entries_or_404(db, payload.entry_ids)
    for entry in entries:
        _delete_entry(db, entry)
    db.commit()
    return BulkStockDeleteResult(deleted=len(entries))


@router.post("/bulk/move", response_model=BulkStockMoveResult)
def bulk_move_stock(payload: BulkStockMove, db: Session = Depends(get_db)):
    if not db.get(Location, payload.location_id):
        raise HTTPException(404, "Location not found")
    entries = _get_entries_or_404(db, payload.entry_ids)
    for entry in entries:
        entry.location_id = payload.location_id
    db.commit()
    for entry in entries:
        db.refresh(entry)
    return BulkStockMoveResult(moved=len(entries), entries=entries)


@router.patch("/{entry_id}", response_model=StockEntryRead)
def update_stock(entry_id: int, payload: StockEntryUpdate, db: Session = Depends(get_db)):
    entry = db.get(StockEntry, entry_id)
    if not entry:
        raise HTTPException(404, "Stock entry not found")
    updates = payload.model_dump(exclude_unset=True)
    # Mirrors add_stock's location_id validation above -- PATCH previously
    # skipped this check and let an unknown location_id fall through to a
    # raw 500 from SQLite's FK enforcement.
    if updates.get("location_id") is not None and not db.get(Location, updates["location_id"]):
        raise HTTPException(404, "Location not found")
    for key, value in updates.items():
        setattr(entry, key, value)
    db.commit()
    db.refresh(entry)
    return entry


@router.post("/{entry_id}/consume", response_model=StockConsumeResult)
def consume_stock(entry_id: int, payload: StockEntryConsume, db: Session = Depends(get_db)):
    entry = db.get(StockEntry, entry_id)
    if not entry:
        raise HTTPException(404, "Stock entry not found")
    fully_consumed, log_id = _consume_entry(
        db, entry, payload.amount, payload.reason, undoable=True
    )
    db.commit()
    if fully_consumed:
        return StockConsumeResult(entry=None, consumption_log_id=log_id)
    db.refresh(entry)
    return StockConsumeResult(entry=entry, consumption_log_id=log_id)


@router.post("/undo/{log_id}", response_model=StockEntryRead, status_code=201)
def undo_consume(log_id: int, db: Session = Depends(get_db)):
    """Reverses a single consume (#160, hardened in #224): atomically
    deletes the ConsumptionLog row `log_id` and recreates the StockEntry
    portion that consume removed -- entirely from the immutable snapshot
    that /{entry_id}/consume wrote onto that log row, never from the request
    body. This is server-authoritative: the request carries no stock data
    (any body is ignored), so a client cannot erase one product's log while
    fabricating stock for another (#224).

    Only rows flagged `undoable` (single consume) qualify; bulk-consume and
    delete/bulk-delete rows -- which the UI never offered Undo for -- are
    rejected with 409. Validation (log exists + undoable, product/location
    still exist) happens before any db.add/db.delete, so a rejected call
    changes nothing. Deleting the log makes undo one-shot: a second call for
    the same id 404s, since the row is already gone."""
    log = db.get(ConsumptionLog, log_id)
    if not log:
        raise HTTPException(404, "Consumption log entry not found")
    if not log.undoable:
        raise HTTPException(409, "This consumption log entry cannot be undone")
    if not db.get(Product, log.product_id):
        raise HTTPException(404, "Product not found")
    if log.undo_location_id is not None and not db.get(Location, log.undo_location_id):
        raise HTTPException(404, "Location not found")
    entry = StockEntry(
        product_id=log.product_id,
        location_id=log.undo_location_id,
        amount=log.amount,
        best_before_date=log.undo_best_before_date,
        purchased_date=log.undo_purchased_date,
        opened_at=log.undo_opened_at,
        price=log.price,
    )
    db.add(entry)
    db.delete(log)
    db.commit()
    db.refresh(entry)
    return entry


@router.delete("/{entry_id}", status_code=204)
def delete_stock(entry_id: int, db: Session = Depends(get_db)):
    entry = db.get(StockEntry, entry_id)
    if not entry:
        raise HTTPException(404, "Stock entry not found")
    _delete_entry(db, entry)
    db.commit()

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.db import get_db
from app.models import Product, ShoppingListItem, StockEntry
from app.routers.stats import low_stock_products_query
from app.schemas import ShoppingListItemCreate, ShoppingListItemRead, ShoppingListItemUpdate

router = APIRouter(prefix="/api/shopping-list", tags=["shopping-list"])


def _display_name(item: ShoppingListItem) -> str:
    # An explicit name always wins (it's how a free-text item is set in the
    # first place, and lets a product-linked item be relabeled without
    # touching the Product itself); otherwise fall back to the linked
    # product's name.
    if item.name:
        return item.name
    return item.product.name if item.product else ""


def _display_unit(item: ShoppingListItem) -> str | None:
    if item.unit:
        return item.unit
    return item.product.quantity_unit if item.product else None


def _to_read(item: ShoppingListItem) -> ShoppingListItemRead:
    return ShoppingListItemRead(
        id=item.id,
        product_id=item.product_id,
        name=_display_name(item),
        amount=item.amount,
        unit=_display_unit(item),
        done=item.done,
        created_at=item.created_at,
    )


@router.get("", response_model=list[ShoppingListItemRead])
def list_shopping_list(db: Session = Depends(get_db)):
    items = (
        db.query(ShoppingListItem)
        .options(joinedload(ShoppingListItem.product))
        # Open items first, then done; newest-first within each group.
        .order_by(ShoppingListItem.done.asc(), ShoppingListItem.created_at.desc())
        .all()
    )
    return [_to_read(item) for item in items]


@router.post("", response_model=ShoppingListItemRead, status_code=201)
def create_shopping_list_item(payload: ShoppingListItemCreate, db: Session = Depends(get_db)):
    if payload.product_id is not None and not db.get(Product, payload.product_id):
        raise HTTPException(404, "Product not found")
    item = ShoppingListItem(**payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return _to_read(item)


@router.delete("/done")
def clear_done_shopping_list_items(db: Session = Depends(get_db)):
    # Declared before /{item_id} -- otherwise "done" would be captured as
    # item_id and 422 on the int conversion.
    deleted = (
        db.query(ShoppingListItem)
        .filter(ShoppingListItem.done.is_(True))
        .delete(synchronize_session=False)
    )
    db.commit()
    return {"deleted": deleted}


@router.post("/add-low-stock", response_model=list[ShoppingListItemRead])
def add_low_stock_items(db: Session = Depends(get_db)):
    """Adds one shopping list item per low-stock product (same definition as
    /api/stats' low_stock_products) that doesn't already have an open
    (not-done) item on the list, so calling this repeatedly is a no-op for
    products already queued. The queued amount restocks up to
    target_stock_level when the product has one set (never less than 1, in
    case stock rose between the low-stock check and this deficit
    computation); products without a target keep the old flat "queue 1"
    behavior."""
    already_listed = {
        product_id
        for (product_id,) in db.query(ShoppingListItem.product_id)
        .filter(ShoppingListItem.product_id.isnot(None), ShoppingListItem.done.is_(False))
        .all()
    }
    products = [p for p in low_stock_products_query(db).all() if p.id not in already_listed]
    current_stock = dict(
        db.query(StockEntry.product_id, func.sum(StockEntry.amount))
        .filter(StockEntry.product_id.in_([p.id for p in products]))
        .group_by(StockEntry.product_id)
        .all()
    )
    created: list[ShoppingListItem] = []
    for product in products:
        if product.target_stock_level is not None:
            deficit = product.target_stock_level - current_stock.get(product.id, 0)
            amount = max(deficit, 1)
        else:
            amount = 1
        item = ShoppingListItem(product_id=product.id, amount=amount, unit=product.quantity_unit)
        db.add(item)
        created.append(item)
    db.commit()
    for item in created:
        db.refresh(item)
    return [_to_read(item) for item in created]


@router.patch("/{item_id}", response_model=ShoppingListItemRead)
def update_shopping_list_item(
    item_id: int, payload: ShoppingListItemUpdate, db: Session = Depends(get_db)
):
    item = db.get(ShoppingListItem, item_id)
    if not item:
        raise HTTPException(404, "Shopping list item not found")
    data = payload.model_dump(exclude_unset=True)
    if "product_id" in data and data["product_id"] is not None:
        if not db.get(Product, data["product_id"]):
            raise HTTPException(404, "Product not found")
    # Validate the *merged* result (existing row + incoming fields) before
    # touching the session -- a PATCH that only sets product_id to null (with
    # name already null/blank) must not be allowed to drop both identities,
    # even though neither field alone looks invalid in isolation. "Blank"
    # matches the create schema: None or "" both count as absent.
    merged_product_id = data.get("product_id", item.product_id)
    merged_name = data.get("name", item.name)
    if merged_product_id is None and not merged_name:
        raise HTTPException(422, "Either product_id or name is required")
    for key, value in data.items():
        setattr(item, key, value)
    db.commit()
    db.refresh(item)
    return _to_read(item)


@router.delete("/{item_id}", status_code=204)
def delete_shopping_list_item(item_id: int, db: Session = Depends(get_db)):
    item = db.get(ShoppingListItem, item_id)
    if not item:
        raise HTTPException(404, "Shopping list item not found")
    db.delete(item)
    db.commit()

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Category, Product
from app.schemas import CategoryCreate, CategoryRead, CategoryUpdate

router = APIRouter(prefix="/api/categories", tags=["categories"])


def _find_by_name_ci(db: Session, name: str) -> Category | None:
    """SQLite's default unique constraint is case-sensitive, but the
    frontend's autocomplete matches case-insensitively -- without this check
    two clients (or one with a stale category list) racing "Dairy" and
    "dairy" would both pass the DB constraint and create duplicates."""
    return db.query(Category).filter(func.lower(Category.name) == name.lower()).first()


@router.get("", response_model=list[CategoryRead])
def list_categories(
    limit: int | None = Query(None, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    # Category.name is unique (see _find_by_name_ci), so no tiebreaker is
    # needed for stable ordering.
    query = db.query(Category).order_by(Category.name).offset(offset)
    if limit is not None:
        query = query.limit(limit)
    return query.all()


@router.post("", response_model=CategoryRead, status_code=201)
def create_category(payload: CategoryCreate, db: Session = Depends(get_db)):
    if _find_by_name_ci(db, payload.name):
        raise HTTPException(409, "A category with that name already exists")
    category = Category(name=payload.name)
    db.add(category)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A category with that name already exists")
    db.refresh(category)
    return category


@router.patch("/{category_id}", response_model=CategoryRead)
def update_category(category_id: int, payload: CategoryUpdate, db: Session = Depends(get_db)):
    category = db.get(Category, category_id)
    if not category:
        raise HTTPException(404, "Category not found")
    existing = _find_by_name_ci(db, payload.name)
    if existing and existing.id != category_id:
        raise HTTPException(409, "A category with that name already exists")
    category.name = payload.name
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "A category with that name already exists")
    db.refresh(category)
    return category


@router.delete("/{category_id}", status_code=204)
def delete_category(category_id: int, db: Session = Depends(get_db)):
    category = db.get(Category, category_id)
    if not category:
        raise HTTPException(404, "Category not found")
    # Unlike Location, deleting a category doesn't block on products still
    # using it -- it just clears their category_id (#72's decision), since
    # a category isn't otherwise load-bearing the way a location is.
    db.query(Product).filter(Product.category_id == category_id).update({"category_id": None})
    db.delete(category)
    db.commit()

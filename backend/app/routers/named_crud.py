"""Shared CRUD for the tables whose only writable field is a unique name.

Location and Category had byte-identical list/create/update routes plus an
identical case-insensitive duplicate check; only their delete rules genuinely
differ (a location blocks on referencing rows, a category detaches them).
This builds the common three routes; each module registers its own delete on
the returned router.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas import NamedRead, NamedWrite


def find_by_name_ci(db: Session, model, name: str):
    """SQLite's default unique constraint is case-sensitive, but the
    frontend's autocomplete matches case-insensitively -- without this check
    two clients (or one with a stale list) racing "Fridge" and "fridge" would
    both pass the DB constraint and create duplicates."""
    return db.query(model).filter(func.lower(model.name) == name.lower()).first()


def named_crud_router(*, model, prefix: str, tag: str, exists_detail: str) -> APIRouter:
    """List/create/update routes for `model`. `exists_detail` is the 409 body
    used for a duplicate name (e.g. "A location with that name already
    exists")."""
    router = APIRouter(prefix=prefix, tags=[tag])

    @router.get("", response_model=list[NamedRead])
    def list_items(
        limit: int | None = Query(None, ge=1, le=1000),
        offset: int = Query(0, ge=0),
        db: Session = Depends(get_db),
    ):
        # name is unique (see find_by_name_ci), so it alone is a stable
        # ordering -- no id tiebreaker needed for pagination.
        query = db.query(model).order_by(model.name).offset(offset)
        if limit is not None:
            query = query.limit(limit)
        return query.all()

    @router.post("", response_model=NamedRead, status_code=201)
    def create_item(payload: NamedWrite, db: Session = Depends(get_db)):
        if find_by_name_ci(db, model, payload.name):
            raise HTTPException(409, exists_detail)
        item = model(name=payload.name)
        db.add(item)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            raise HTTPException(409, exists_detail) from None
        db.refresh(item)
        return item

    @router.patch("/{item_id}", response_model=NamedRead)
    def update_item(item_id: int, payload: NamedWrite, db: Session = Depends(get_db)):
        item = db.get(model, item_id)
        if not item:
            raise HTTPException(404, f"{model.__name__} not found")
        existing = find_by_name_ci(db, model, payload.name)
        if existing and existing.id != item_id:
            raise HTTPException(409, exists_detail)
        item.name = payload.name
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            raise HTTPException(409, exists_detail) from None
        db.refresh(item)
        return item

    return router

from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Location, Product, StockEntry
from app.routers.named_crud import named_crud_router

router = named_crud_router(
    model=Location,
    prefix="/api/locations",
    tag="locations",
    exists_detail="A location with that name already exists",
)


@router.delete("/{location_id}", status_code=204)
def delete_location(location_id: int, db: Session = Depends(get_db)):
    location = db.get(Location, location_id)
    if not location:
        raise HTTPException(404, "Location not found")
    has_stock = db.query(StockEntry).filter(StockEntry.location_id == location_id).first()
    if has_stock:
        raise HTTPException(409, "Location still has stock entries; move or remove them first")
    is_default_for_product = (
        db.query(Product).filter(Product.default_location_id == location_id).first()
    )
    if is_default_for_product:
        raise HTTPException(409, "Location is a product's default location; change that first")
    db.delete(location)
    db.commit()

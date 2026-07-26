from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Category, Product
from app.routers.named_crud import named_crud_router

router = named_crud_router(
    model=Category,
    prefix="/api/categories",
    tag="categories",
    exists_detail="A category with that name already exists",
)


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

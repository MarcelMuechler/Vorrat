from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Product
from app.off_client import lookup_off
from app.schemas import ProductRead
from app.utils import normalize_barcode

router = APIRouter(prefix="/api/barcode", tags=["barcode"])


@router.get("/{code}")
async def lookup_barcode(code: str, db: Session = Depends(get_db)):
    code = normalize_barcode(code) or code
    product = db.query(Product).filter(Product.barcode == code).first()
    if product:
        return {"source": "local", "product": ProductRead.model_validate(product)}

    off_product = await lookup_off(code)
    if off_product:
        return {"source": "off", "product": off_product}

    raise HTTPException(404, {"source": "none"})

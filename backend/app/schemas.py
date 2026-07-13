from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class LocationCreate(BaseModel):
    name: str


class LocationUpdate(BaseModel):
    name: str


class LocationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    created_at: datetime


def _strip_name(v: str | None) -> str | None:
    return v.strip() if isinstance(v, str) else v


class ProductCreate(BaseModel):
    barcode: str | None = None
    name: str = Field(min_length=1)
    brand: str | None = None
    image_url: str | None = None
    category: str | None = None
    quantity_unit: str = "pcs"
    default_location_id: int | None = None
    default_best_before_days: int | None = None

    _strip_name = field_validator("name", mode="before")(_strip_name)


class ProductUpdate(BaseModel):
    barcode: str | None = None
    name: str | None = Field(default=None, min_length=1)
    brand: str | None = None
    image_url: str | None = None
    category: str | None = None
    quantity_unit: str | None = None
    default_location_id: int | None = None
    default_best_before_days: int | None = None

    _strip_name = field_validator("name", mode="before")(_strip_name)


class ProductRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    barcode: str | None
    name: str
    brand: str | None
    image_url: str | None
    category: str | None
    quantity_unit: str
    default_location_id: int | None
    default_best_before_days: int | None
    created_at: datetime


class StockEntryCreate(BaseModel):
    product_id: int
    location_id: int | None = None
    amount: float = Field(gt=0)
    best_before_date: date | None = None
    purchased_date: date | None = None


class StockEntryUpdate(BaseModel):
    location_id: int | None = None
    amount: float | None = Field(default=None, gt=0)
    best_before_date: date | None = None
    purchased_date: date | None = None


class StockEntryConsume(BaseModel):
    amount: float = Field(gt=0)


class StockEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    location_id: int | None
    amount: float
    best_before_date: date | None
    purchased_date: date | None
    created_at: datetime
    updated_at: datetime


class StockOverviewItem(StockEntryRead):
    product_name: str
    product_barcode: str | None
    location_name: str | None
    status: str


class AppSettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    expiring_soon_days: int


class AppSettingsUpdate(BaseModel):
    expiring_soon_days: int = Field(gt=0)

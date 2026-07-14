from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.utils import normalize_barcode


def _strip_name(v: str | None) -> str | None:
    return v.strip() if isinstance(v, str) else v


class LocationCreate(BaseModel):
    name: str


class LocationUpdate(BaseModel):
    name: str


class LocationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    created_at: datetime


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1)

    _strip_name = field_validator("name", mode="before")(_strip_name)


class CategoryUpdate(BaseModel):
    name: str = Field(min_length=1)

    _strip_name = field_validator("name", mode="before")(_strip_name)


class CategoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    created_at: datetime


class ProductCreate(BaseModel):
    barcode: str | None = None
    name: str = Field(min_length=1)
    image_url: str | None = None
    category_id: int | None = None
    quantity_unit: str = "pcs"
    default_location_id: int | None = None
    default_best_before_days: int | None = None
    default_open_shelf_life_days: int | None = None
    low_stock_threshold: float | None = Field(default=None, gt=0)

    _strip_name = field_validator("name", mode="before")(_strip_name)
    _normalize_barcode = field_validator("barcode", mode="before")(normalize_barcode)


class ProductUpdate(BaseModel):
    barcode: str | None = None
    name: str | None = Field(default=None, min_length=1)
    image_url: str | None = None
    category_id: int | None = None
    quantity_unit: str | None = None
    default_location_id: int | None = None
    default_best_before_days: int | None = None
    default_open_shelf_life_days: int | None = None
    low_stock_threshold: float | None = Field(default=None, gt=0)

    _strip_name = field_validator("name", mode="before")(_strip_name)
    _normalize_barcode = field_validator("barcode", mode="before")(normalize_barcode)


class ProductRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    barcode: str | None
    name: str
    image_url: str | None
    category_id: int | None
    category_name: str | None
    quantity_unit: str
    default_location_id: int | None
    default_best_before_days: int | None
    default_open_shelf_life_days: int | None
    low_stock_threshold: float | None
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
    opened_at: date | None = None


class StockEntryConsume(BaseModel):
    amount: float = Field(gt=0)
    reason: Literal["used", "spoiled"] = "used"


class StockEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    location_id: int | None
    amount: float
    best_before_date: date | None
    purchased_date: date | None
    opened_at: date | None
    created_at: datetime
    updated_at: datetime


class StockOverviewItem(StockEntryRead):
    product_name: str
    product_barcode: str | None
    product_category: str | None
    product_low_stock_threshold: float | None
    location_name: str | None
    status: str


class BulkStockEntryIds(BaseModel):
    entry_ids: list[int] = Field(min_length=1)


class BulkStockConsume(BulkStockEntryIds):
    reason: Literal["used", "spoiled"] = "used"


class BulkStockMove(BulkStockEntryIds):
    location_id: int


class BulkStockConsumeResult(BaseModel):
    consumed: int


class BulkStockDeleteResult(BaseModel):
    deleted: int


class BulkStockMoveResult(BaseModel):
    moved: int
    entries: list[StockEntryRead]


class StockImportRowError(BaseModel):
    row: int
    error: str


class StockImportResult(BaseModel):
    imported: int
    errors: list[StockImportRowError]


class ConsumptionLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    amount: float
    reason: str
    quantity_unit: str | None = None
    created_at: datetime


class ConsumptionLogItem(ConsumptionLogRead):
    product_name: str


class AppSettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    expiring_soon_days: int


class AppSettingsUpdate(BaseModel):
    expiring_soon_days: int = Field(gt=0)


class StatsRead(BaseModel):
    total_products: int
    total_stock_entries: int
    expired: int
    expiring_soon: int
    low_stock_products: int
    earliest_expiry: date | None


class ShoppingListItemCreate(BaseModel):
    product_id: int | None = None
    name: str | None = Field(default=None, min_length=1)
    amount: float = Field(default=1, gt=0)
    unit: str | None = None

    _strip_name = field_validator("name", mode="before")(_strip_name)

    @model_validator(mode="after")
    def _require_product_or_name(self) -> "ShoppingListItemCreate":
        if self.product_id is None and not self.name:
            raise ValueError("Either product_id or name is required")
        return self


class ShoppingListItemUpdate(BaseModel):
    product_id: int | None = None
    name: str | None = Field(default=None, min_length=1)
    amount: float | None = Field(default=None, gt=0)
    unit: str | None = None
    done: bool | None = None

    _strip_name = field_validator("name", mode="before")(_strip_name)


class ShoppingListItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int | None
    name: str
    amount: float
    unit: str | None
    done: bool
    created_at: datetime

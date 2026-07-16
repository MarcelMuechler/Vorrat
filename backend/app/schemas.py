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
    target_stock_level: float | None = Field(default=None, gt=0)

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
    target_stock_level: float | None = Field(default=None, gt=0)

    _strip_name = field_validator("name", mode="before")(_strip_name)
    _normalize_barcode = field_validator("barcode", mode="before")(normalize_barcode)


class ProductRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    barcode: str | None
    extra_barcodes: list[str]
    name: str
    image_url: str | None
    category_id: int | None
    category_name: str | None
    quantity_unit: str
    default_location_id: int | None
    default_best_before_days: int | None
    default_open_shelf_life_days: int | None
    low_stock_threshold: float | None
    target_stock_level: float | None
    created_at: datetime


class ProductBarcodeCreate(BaseModel):
    code: str = Field(min_length=1)

    _normalize_barcode = field_validator("code", mode="before")(normalize_barcode)


class StockEntryCreate(BaseModel):
    product_id: int
    location_id: int | None = None
    amount: float = Field(gt=0)
    best_before_date: date | None = None
    purchased_date: date | None = None
    # Per-unit price -- see StockEntry.price's docstring in models.py for
    # why per-unit rather than a total for the whole entry.
    price: float | None = Field(default=None, ge=0)


class StockEntryUpdate(BaseModel):
    location_id: int | None = None
    amount: float | None = Field(default=None, gt=0)
    best_before_date: date | None = None
    purchased_date: date | None = None
    opened_at: date | None = None
    price: float | None = Field(default=None, ge=0)


class StockEntryConsume(BaseModel):
    amount: float = Field(gt=0)
    reason: Literal["used", "spoiled"] = "used"


class StockUndoConsume(BaseModel):
    """Body for POST /stock/undo/{log_id}: the exact fields needed to
    recreate the StockEntry that /{entry_id}/consume removed or shrank --
    supplied by the frontend, which already held this batch's data before
    it called consume, rather than persisted server-side (#160)."""

    product_id: int
    location_id: int | None = None
    amount: float = Field(gt=0)
    best_before_date: date | None = None
    purchased_date: date | None = None
    opened_at: date | None = None
    price: float | None = Field(default=None, ge=0)


class StockEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    location_id: int | None
    amount: float
    best_before_date: date | None
    purchased_date: date | None
    opened_at: date | None
    price: float | None
    created_at: datetime
    updated_at: datetime


class StockConsumeResult(BaseModel):
    """consume_stock's response: the surviving entry (or null if it was fully
    consumed and deleted) plus the id of the ConsumptionLog row that was
    written, which the frontend needs to later call /stock/undo/{log_id}
    (#160) if the user hits Undo."""

    entry: StockEntryRead | None
    consumption_log_id: int


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
    # Snapshotted per-unit price from the source StockEntry at
    # consume/spoil time -- see ConsumptionLog.price's docstring.
    price: float | None = None
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
    # Sum of amount * price across current stock entries that have a price
    # set -- entries with no price are simply skipped (not treated as
    # free), so this is a lower bound whenever some entries are unpriced.
    # 0 (not null) when nothing is priced, matching the other counters here.
    total_value: float


class ShoppingListItemCreate(BaseModel):
    product_id: int | None = None
    name: str | None = Field(default=None, min_length=1)
    amount: float = Field(default=1, gt=0)
    unit: str | None = None
    category_id: int | None = None

    _strip_name = field_validator("name", mode="before")(_strip_name)

    @model_validator(mode="after")
    def _require_product_or_name(self) -> "ShoppingListItemCreate":
        if self.product_id is None and not self.name:
            raise ValueError("Either product_id or name is required")
        return self

    @model_validator(mode="after")
    def _category_only_for_free_text(self) -> "ShoppingListItemCreate":
        if self.category_id is not None and self.product_id is not None:
            raise ValueError("category_id can only be set on a free-text item (product_id must be null)")
        return self


class ShoppingListItemUpdate(BaseModel):
    product_id: int | None = None
    name: str | None = Field(default=None, min_length=1)
    amount: float | None = Field(default=None, gt=0)
    unit: str | None = None
    done: bool | None = None
    category_id: int | None = None

    _strip_name = field_validator("name", mode="before")(_strip_name)


class ShoppingListItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int | None
    name: str
    amount: float
    unit: str | None
    done: bool
    category_id: int | None
    category_name: str | None
    created_at: datetime

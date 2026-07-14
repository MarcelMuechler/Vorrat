from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Location(Base):
    __tablename__ = "locations"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class Category(Base):
    """A real entity (#72) rather than free text on Product -- renaming or
    deleting one here is instantly reflected on every product that
    references it, no bulk-update needed."""

    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class Product(Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True)
    barcode: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    name: Mapped[str] = mapped_column(String)
    image_url: Mapped[str | None] = mapped_column(String, nullable=True)
    category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"), nullable=True)
    quantity_unit: Mapped[str] = mapped_column(String, default="pcs")
    default_location_id: Mapped[int | None] = mapped_column(
        ForeignKey("locations.id"), nullable=True
    )
    default_best_before_days: Mapped[int | None] = mapped_column(nullable=True)
    default_open_shelf_life_days: Mapped[int | None] = mapped_column(nullable=True)
    # No sensible instance-wide default -- "low" is entirely product-specific
    # (0.2kg of flour vs. 1 jar of jam mean very different things). Null means
    # the low-stock feature is simply off for that product.
    low_stock_threshold: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    default_location: Mapped[Location | None] = relationship()
    category: Mapped[Category | None] = relationship()

    @property
    def category_name(self) -> str | None:
        return self.category.name if self.category else None


class AppSettings(Base):
    """Single-row table for app-wide settings editable at runtime (as opposed
    to config.py's env-var settings, fixed at process start) -- e.g. the
    "expiring soon" threshold, previously only changeable via an env var."""

    __tablename__ = "app_settings"

    id: Mapped[int] = mapped_column(primary_key=True, default=1)
    expiring_soon_days: Mapped[int] = mapped_column(default=3)


class StockEntry(Base):
    __tablename__ = "stock_entries"

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    location_id: Mapped[int | None] = mapped_column(ForeignKey("locations.id"), nullable=True)
    amount: Mapped[float] = mapped_column(Float)
    best_before_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    purchased_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    opened_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    product: Mapped[Product] = relationship()
    location: Mapped[Location | None] = relationship()


class ShoppingListItem(Base):
    """A to-buy list, separate from stock -- product_id links back to a known
    Product (for a resolved display name/unit), but name is a free-text
    fallback/override so a one-off item ("birthday candles") doesn't need a
    Product created just to go on the list. Enforcing "product_id or name"
    is left to the Pydantic create schema rather than a DB constraint, matching
    how validation elsewhere in this codebase favors the API layer over
    SQLite CHECK constraints."""

    __tablename__ = "shopping_list_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int | None] = mapped_column(ForeignKey("products.id"), nullable=True)
    name: Mapped[str | None] = mapped_column(String, nullable=True)
    amount: Mapped[float] = mapped_column(Float, default=1)
    unit: Mapped[str | None] = mapped_column(String, nullable=True)
    done: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    product: Mapped[Product | None] = relationship()


class ConsumptionLog(Base):
    """Append-only record of stock leaving via consume/delete, kept after the
    StockEntry itself is gone -- just enough to answer "how much did I waste"
    without a full transaction ledger (every purchase/transfer/correction)."""

    __tablename__ = "consumption_log"

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    amount: Mapped[float] = mapped_column(Float)
    reason: Mapped[str] = mapped_column(String)  # "used" | "spoiled"
    # Snapshotted from Product.quantity_unit at write time (not read live via
    # the relationship) so a later unit change on the product doesn't
    # retroactively reinterpret historic log rows. Nullable because rows
    # written before this column existed have no snapshot to backfill beyond
    # the product's *current* unit (see the migration).
    quantity_unit: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    product: Mapped[Product] = relationship()

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
    # How much add-low-stock (shopping_list.py) should restock up to, once a
    # product dips to/below low_stock_threshold. Null keeps the old
    # behavior -- queue exactly 1 unit -- so this is opt-in per product, not
    # a backfilled default.
    target_stock_level: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    default_location: Mapped[Location | None] = relationship()
    category: Mapped[Category | None] = relationship()
    # Extra scannable codes for this product (#208) -- alternate pack sizes
    # or regional/reprinted barcodes for the same physical item, beyond the
    # single `barcode` column above. Cascade-deleted with the product: unlike
    # StockEntry (blocked) or ShoppingListItem/ConsumptionLog (detached/bulk
    # deleted) in delete_product, these are pure lookup aliases with no
    # standalone meaning once the product is gone.
    barcodes: Mapped[list["ProductBarcode"]] = relationship(
        cascade="all, delete-orphan", order_by="ProductBarcode.id"
    )

    @property
    def category_name(self) -> str | None:
        return self.category.name if self.category else None

    @property
    def extra_barcodes(self) -> list[str]:
        return [b.code for b in self.barcodes]


class ProductBarcode(Base):
    """A child table (#208) rather than widening `Product.barcode` to a list
    column -- lets barcode.py's local-DB-first lookup match a scan against
    any of a product's codes with a plain query, and keeps the single
    "canonical" barcode column and its existing unique constraint/QR-label
    behavior (product_edit_screen.dart's VORRAT-<id> synthetic label) intact."""

    __tablename__ = "product_barcodes"

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    code: Mapped[str] = mapped_column(String, unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


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
    # Price *per unit* (Product.quantity_unit), not the total paid for the
    # whole entry -- amount can shrink via partial consumption
    # (_consume_entry in stock.py), so a per-unit price stays correct
    # against whatever's left, whereas a fixed total would silently
    # overstate value after any partial use. Optional: entries created
    # before this existed, or where the user just doesn't track cost, have
    # no price and are skipped (not treated as free) by the total-value sum
    # in stats.py.
    price: Mapped[float | None] = mapped_column(Float, nullable=True)
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
    is left to the API layer (the create schema's model_validator, and the
    PATCH route re-checking the merged result) rather than a DB constraint,
    matching how validation elsewhere in this codebase favors the API layer
    over SQLite CHECK constraints.

    category_id (#122) is only meaningful for free-text items -- a
    product-linked item already has a category via product.category, so the
    API layer rejects setting both at once rather than letting one silently
    shadow the other."""

    __tablename__ = "shopping_list_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int | None] = mapped_column(ForeignKey("products.id"), nullable=True)
    name: Mapped[str | None] = mapped_column(String, nullable=True)
    amount: Mapped[float] = mapped_column(Float, default=1)
    unit: Mapped[str | None] = mapped_column(String, nullable=True)
    done: Mapped[bool] = mapped_column(Boolean, default=False)
    category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    product: Mapped[Product | None] = relationship()
    category: Mapped[Category | None] = relationship()

    @property
    def category_name(self) -> str | None:
        # A free-text item's own category wins; a product-linked item
        # without one of its own falls back to the product's category, so
        # existing product-linked grouping/display isn't disrupted by this
        # column's addition.
        if self.category:
            return self.category.name
        return self.product.category_name if self.product else None


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
    # Snapshotted from the source StockEntry.price at the moment it's
    # consumed/spoiled (not looked up live) -- same rationale as
    # quantity_unit above: a later price edit (or the entry being deleted
    # entirely) mustn't retroactively reinterpret what this historic row
    # cost. Null if the source entry had no price, or for rows written
    # before this column existed.
    price: Mapped[float | None] = mapped_column(Float, nullable=True)
    # Server-authoritative undo (#224). Only a *single* consume
    # (/{entry_id}/consume) is reversible, and it must restore exactly what
    # it removed -- never client-supplied replacement values. So the row that
    # is reversible is flagged `undoable=True` and carries an immutable
    # snapshot of the StockEntry fields not already captured above
    # (product_id/amount/price are). Bulk-consume and delete/bulk-delete rows
    # leave `undoable` at its default False (and never offered Undo in the
    # UI), so their snapshot columns stay null and undo_consume rejects them.
    # Undo reconstructs the removed portion from (product_id, amount, price)
    # plus these columns, then deletes the log -- so it can only ever run
    # once.
    undoable: Mapped[bool] = mapped_column(Boolean, server_default="0", default=False)
    undo_location_id: Mapped[int | None] = mapped_column(nullable=True)
    undo_best_before_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    undo_purchased_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    undo_opened_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    product: Mapped[Product] = relationship()

"""normalize UPC barcodes to EAN-13

Revision ID: b7a1c9d43e05
Revises: 356f3a01fbd5
Create Date: 2026-07-27

Existing rows were stored in whatever form the scanner reported (#328). Fold
the UPC-A/UPC-E ones into EAN-13 so they match newly scanned codes, which
normalize_barcode now converts on the way in.

Rows whose normalized form would collide with an existing barcode are left
untouched -- both columns are UNIQUE, and merging the two products they belong
to is a user decision (#333), not something a migration should guess at.
"""

import sqlalchemy as sa
from alembic import op

from app.utils import normalize_barcode

revision = "b7a1c9d43e05"
down_revision = "356f3a01fbd5"
branch_labels = None
depends_on = None


def _renormalize(conn, table: str, column: str) -> None:
    rows = conn.execute(sa.text(f"SELECT id, {column} FROM {table} WHERE {column} IS NOT NULL"))
    taken = set()
    updates = []
    for row_id, code in rows:
        normalized = normalize_barcode(code)
        taken.add(code)
        if normalized != code:
            updates.append((row_id, normalized))
    for row_id, normalized in updates:
        if normalized in taken:
            continue
        conn.execute(
            sa.text(f"UPDATE {table} SET {column} = :new WHERE id = :id"),
            {"new": normalized, "id": row_id},
        )
        # The code being replaced is never freed for reuse: normalize_barcode
        # only ever produces 13-digit codes, so no other row can normalize
        # *to* the 12/8-digit form this one is vacating.
        taken.add(normalized)


def upgrade() -> None:
    conn = op.get_bind()
    _renormalize(conn, "products", "barcode")
    _renormalize(conn, "product_barcodes", "code")


def downgrade() -> None:
    # Not reversible: a 13-digit code with a leading zero is a legitimate
    # EAN-13 in its own right, so there's no way to tell which rows this
    # migration created.
    pass

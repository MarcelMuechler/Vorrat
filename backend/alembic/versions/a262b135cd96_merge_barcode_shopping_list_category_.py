"""merge barcode, shopping-list category, and price heads

Revision ID: a262b135cd96
Revises: 1bfb072b3f46, 2185a443e1c0, c1969f63762b
Create Date: 2026-07-16 09:50:28.598500

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a262b135cd96'
down_revision: Union[str, Sequence[str], None] = ('1bfb072b3f46', '2185a443e1c0', 'c1969f63762b')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass

#!/usr/bin/env python3
"""
Regression test for N+1 query issue in GET /api/products.

Uses SQLAlchemy's event system to count statements while calling the list route
via TestClient with an in-memory sqlite DB seeded with several products with
alternate barcodes. Fails before the fix (selectinload not applied), passes after.

Without selectinload: 1 main query + N per-product barcode queries = 1 + 3 = 4 total
With selectinload: 1 main query + 1 barcodes query = 2 total
"""

import tempfile
from pathlib import Path

from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session
from fastapi.testclient import TestClient

from app.db import Base
from app.main import app
from app.models import Product, ProductBarcode, Category
from app.db import get_db


def test_products_list_query_count():
    """Test that GET /api/products doesn't have N+1 barcode queries."""

    # Use temporary file-based SQLite (can't use in-memory for this test as it needs proper pooling)
    temp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    db_path = temp_db.name
    temp_db.close()

    try:
        engine = create_engine(f"sqlite:///{db_path}", connect_args={"check_same_thread": False})
        Base.metadata.create_all(engine)

        # Seed with test data: 3 products, each with 2 alternate barcodes
        with Session(engine) as session:
            # Create a category
            category = Category(id=1, name="Test Category")
            session.add(category)

            # Create products with barcodes
            for i in range(1, 4):
                product = Product(
                    id=i,
                    name=f"Product {i}",
                    barcode=f"BARCODE_{i}_MAIN",
                    category_id=1,
                )
                session.add(product)

                # Add 2 alternate barcodes for each product
                for j in range(1, 3):
                    barcode = ProductBarcode(
                        product_id=i,
                        code=f"BARCODE_{i}_ALT_{j}",
                    )
                    session.add(barcode)

            session.commit()

        # Count SQL statements during the API call
        query_count = 0

        def count_statement(conn, cursor, statement, parameters, context, executemany):
            nonlocal query_count
            query_count += 1

        # Create test client and dependency override
        def override_get_db():
            with Session(engine) as session:
                yield session

        app.dependency_overrides[get_db] = override_get_db

        try:
            client = TestClient(app)

            # Count queries during the request
            event.listen(engine, "before_cursor_execute", count_statement)
            try:
                response = client.get("/api/products")
            finally:
                event.remove(engine, "before_cursor_execute", count_statement)

            assert response.status_code == 200
            data = response.json()

            # Verify we got our 3 products
            assert len(data) == 3

            # Verify each product has its extra_barcodes populated
            for product in data:
                assert product["extra_barcodes"] == [
                    f"BARCODE_{product['id']}_ALT_1",
                    f"BARCODE_{product['id']}_ALT_2",
                ], f"Product {product['id']} barcodes not loaded correctly"

            # With the fix (selectinload): 1 main query + 1 barcodes query = 2
            # Without fix: 1 + N barcodes queries = 4
            # We allow up to 3 to account for possible sqlite pragmas or internal queries
            max_queries = 3

            print(f"Total queries executed: {query_count}")
            assert query_count <= max_queries, (
                f"Expected <= {max_queries} queries (selectinload applied), "
                f"but got {query_count} (N+1 not fixed?)"
            )
            print(f"✓ Query count test passed ({query_count} <= {max_queries})")

        finally:
            app.dependency_overrides.clear()

    finally:
        Path(db_path).unlink(missing_ok=True)


if __name__ == "__main__":
    test_products_list_query_count()

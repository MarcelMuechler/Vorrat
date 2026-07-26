"""Stock CSV export/import.

Ported from smoke_test.sh, which was the only coverage for these routes.
"""

import csv
import io

from app.routers.stock import IMPORT_CSV_MAX_BYTES


def _rows(csv_text: str) -> list[dict]:
    return list(csv.DictReader(io.StringIO(csv_text)))


def _import(client, csv_text: str):
    return client.post(
        "/api/stock/import.csv", content=csv_text.encode(), headers={"content-type": "text/csv"}
    )


def test_export_includes_the_fields_that_affect_correctness(client):
    product = client.post(
        "/api/products", json={"name": "Milk", "barcode": "111", "quantity_unit": "l"}
    ).json()
    location = client.post("/api/locations", json={"name": "Fridge"}).json()
    client.post(
        "/api/stock",
        json={
            "product_id": product["id"],
            "location_id": location["id"],
            "amount": 2,
            "best_before_date": "2030-01-01",
            "purchased_date": "2029-12-01",
            "price": 1.5,
        },
    )

    response = client.get("/api/stock/export.csv")
    assert response.status_code == 200
    assert "attachment; filename=stock.csv" in response.headers["content-disposition"]

    (row,) = _rows(response.text)
    assert row["product_name"] == "Milk"
    assert row["barcode"] == "111"
    assert row["quantity_unit"] == "l"
    assert row["location"] == "Fridge"
    assert row["amount"] == "2.0"
    assert row["best_before_date"] == "2030-01-01"
    assert row["purchased_date"] == "2029-12-01"
    assert row["price"] == "1.5"


def test_export_import_round_trips(client):
    product = client.post(
        "/api/products", json={"name": "Milk", "barcode": "111", "quantity_unit": "l"}
    ).json()
    client.post("/api/locations", json={"name": "Fridge"})
    entry = client.post(
        "/api/stock",
        json={
            "product_id": product["id"],
            "amount": 2,
            "best_before_date": "2030-01-01",
            "price": 1.5,
        },
    ).json()
    # opened_at isn't part of StockEntryCreate -- it's only ever set later,
    # via PATCH (the frontend's "mark opened" action).
    client.patch(f"/api/stock/{entry['id']}", json={"opened_at": "2029-06-01"})

    exported = client.get("/api/stock/export.csv").text
    response = _import(client, exported)
    assert response.status_code == 200
    assert response.json() == {"imported": 1, "errors": []}

    items = client.get("/api/stock").json()
    assert len(items) == 2
    reimported = items[-1]
    assert reimported["amount"] == 2
    assert reimported["best_before_date"] == "2030-01-01"
    assert reimported["opened_at"] == "2029-06-01"
    assert reimported["price"] == 1.5


def test_import_creates_missing_products_and_locations(client):
    response = _import(
        client, "product_name,location,amount\nNew Product,New Location,3\n"
    )
    assert response.json() == {"imported": 1, "errors": []}

    assert any(p["name"] == "New Product" for p in client.get("/api/products").json())
    assert any(loc["name"] == "New Location" for loc in client.get("/api/locations").json())


def test_import_reuses_an_existing_product_by_barcode(client):
    client.post("/api/products", json={"name": "Milk", "barcode": "111"})

    _import(client, "product_name,barcode,amount\nDifferent Name,111,1\n")

    products = [p for p in client.get("/api/products").json() if p["barcode"] == "111"]
    assert len(products) == 1
    assert products[0]["name"] == "Milk"  # existing product kept, not renamed


def test_import_does_not_rewrite_an_existing_products_unit(client):
    client.post("/api/products", json={"name": "Milk", "barcode": "111", "quantity_unit": "l"})

    _import(client, "product_name,barcode,quantity_unit,amount\nMilk,111,kg,1\n")

    (product,) = [p for p in client.get("/api/products").json() if p["barcode"] == "111"]
    assert product["quantity_unit"] == "l"


def test_import_reports_bad_rows_without_aborting_the_good_ones(client):
    response = _import(
        client,
        "product_name,amount\n"
        "Good,1\n"
        ",2\n"  # missing name
        "Bad Amount,nope\n"
        "Negative,-1\n"
        "Also Good,3\n",
    )
    body = response.json()
    assert body["imported"] == 2
    assert [e["row"] for e in body["errors"]] == [2, 3, 4]


def test_import_ignores_the_derived_status_column(client):
    response = _import(client, "product_name,amount,status\nMilk,1,expired\n")
    assert response.json()["imported"] == 1
    (item,) = client.get("/api/stock").json()
    assert item["status"] == "ok"  # recomputed, not read from the file


def test_import_accepts_an_old_format_file_missing_the_newer_columns(client):
    response = _import(client, "product_name,amount,best_before_date\nMilk,1,2030-01-01\n")
    assert response.json() == {"imported": 1, "errors": []}
    (item,) = client.get("/api/stock").json()
    assert item["opened_at"] is None
    assert item["price"] is None


def test_import_rejects_non_utf8(client):
    response = client.post(
        "/api/stock/import.csv",
        content=b"product_name,amount\n\xff\xfe,1\n",
        headers={"content-type": "text/csv"},
    )
    assert response.status_code == 400


def test_import_rejects_an_oversized_upload(client):
    oversized = "product_name,amount\n" + ("Milk,1\n" * 1)
    oversized += "x" * (IMPORT_CSV_MAX_BYTES + 1)
    response = client.post(
        "/api/stock/import.csv",
        content=oversized.encode(),
        headers={"content-type": "text/csv"},
    )
    assert response.status_code == 413


def test_csv_formula_injection_survives_a_round_trip(client):
    """A leading-apostrophe name must come back intact, not stripped."""
    product = client.post("/api/products", json={"name": "'Nduja"}).json()
    client.post("/api/stock", json={"product_id": product["id"], "amount": 1})

    exported = client.get("/api/stock/export.csv").text
    assert "''Nduja" in exported  # escaped on the way out

    _import(client, exported)
    names = [p["name"] for p in client.get("/api/products").json()]
    assert names.count("'Nduja") == 1  # unescaped back to the original, no duplicate

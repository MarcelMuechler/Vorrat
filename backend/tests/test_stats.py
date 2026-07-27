from datetime import date, timedelta


def _add_product(client, **kwargs):
    return client.post("/api/products", json={"name": "Milk", **kwargs}).json()


def _add_entry(client, product_id, amount=1, best_before_date=None, price=None):
    payload = {"product_id": product_id, "amount": amount}
    if best_before_date is not None:
        payload["best_before_date"] = best_before_date.isoformat()
    if price is not None:
        payload["price"] = price
    return client.post("/api/stock", json=payload).json()


def test_stats_on_empty_db(client):
    response = client.get("/api/stats")
    assert response.status_code == 200
    assert response.json() == {
        "total_products": 0,
        "total_stock_entries": 0,
        "expired": 0,
        "expiring_soon": 0,
        "low_stock_products": 0,
        "earliest_expiry": None,
        "total_value": 0.0,
        "attention": [],
    }


def test_stats_counts_expired_and_expiring_soon(client):
    product = _add_product(client)
    _add_entry(client, product["id"], best_before_date=date.today() - timedelta(days=1))
    _add_entry(client, product["id"], best_before_date=date.today() + timedelta(days=1))
    _add_entry(client, product["id"], best_before_date=date.today() + timedelta(days=30))

    response = client.get("/api/stats")
    body = response.json()
    assert body["total_products"] == 1
    assert body["total_stock_entries"] == 3
    assert body["expired"] == 1
    assert body["expiring_soon"] == 1
    assert body["earliest_expiry"] == (date.today() - timedelta(days=1)).isoformat()


def test_stats_earliest_expiry_skips_does_not_spoil(client):
    canned = client.post(
        "/api/products", json={"name": "Tomatoes", "does_not_spoil": True}
    ).json()
    _add_entry(client, canned["id"], best_before_date=date.today() - timedelta(days=1))

    body = client.get("/api/stats").json()
    assert body["expired"] == 0
    assert body["earliest_expiry"] is None

    perishable = _add_product(client)
    _add_entry(client, perishable["id"], best_before_date=date.today() + timedelta(days=5))

    body = client.get("/api/stats").json()
    assert body["earliest_expiry"] == (date.today() + timedelta(days=5)).isoformat()


def test_stats_attention_names_what_needs_using_up(client):
    # #327: the counters alone can only produce "3 items expired"; HA needs
    # the names to say which. Soonest first, and capped.
    product = client.post("/api/products", json={"name": "Milk", "quantity_unit": "l"}).json()
    _add_entry(client, product["id"], amount=1, best_before_date=date.today() + timedelta(days=1))
    _add_entry(client, product["id"], amount=2, best_before_date=date.today() - timedelta(days=2))
    _add_entry(client, product["id"], amount=3, best_before_date=date.today() + timedelta(days=90))

    attention = client.get("/api/stats").json()["attention"]
    assert [item["status"] for item in attention] == ["expired", "expiring_soon"]
    assert attention[0] == {
        "product": "Milk",
        "amount": 2,
        "unit": "l",
        "expiry": (date.today() - timedelta(days=2)).isoformat(),
        "status": "expired",
    }


def test_stats_attention_skips_does_not_spoil(client):
    canned = client.post("/api/products", json={"name": "Beans", "does_not_spoil": True}).json()
    _add_entry(client, canned["id"], best_before_date=date.today() - timedelta(days=1))

    assert client.get("/api/stats").json()["attention"] == []


def test_stats_low_stock_products_matches_threshold(client):
    product = client.post(
        "/api/products", json={"name": "Flour", "low_stock_threshold": 2}
    ).json()
    _add_entry(client, product["id"], amount=1)

    response = client.get("/api/stats")
    assert response.json()["low_stock_products"] == 1

    # Restocking above the threshold should drop it out of "low stock".
    _add_entry(client, product["id"], amount=5)
    response = client.get("/api/stats")
    assert response.json()["low_stock_products"] == 0


def test_stats_total_value_skips_unpriced_entries(client):
    product = _add_product(client)
    _add_entry(client, product["id"], amount=2, price=1.5)  # 3.0
    _add_entry(client, product["id"], amount=10)  # no price, skipped entirely

    response = client.get("/api/stats")
    assert response.json()["total_value"] == 3.0

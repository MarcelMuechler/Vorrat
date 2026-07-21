from datetime import date, timedelta


def _add_entry(client, best_before_date=None):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    payload = {"product_id": product["id"], "amount": 1}
    if best_before_date is not None:
        payload["best_before_date"] = best_before_date.isoformat()
    entry = client.post("/api/stock", json=payload).json()
    return entry["id"]


def _status_of(client, entry_id):
    items = client.get("/api/stock").json()
    (item,) = [i for i in items if i["id"] == entry_id]
    return item["status"]


def test_stock_entry_with_no_best_before_date_is_ok(client):
    entry_id = _add_entry(client, best_before_date=None)
    assert _status_of(client, entry_id) == "ok"


def test_stock_entry_far_in_future_is_ok(client):
    entry_id = _add_entry(client, best_before_date=date.today() + timedelta(days=30))
    assert _status_of(client, entry_id) == "ok"


def test_stock_entry_within_expiring_soon_window_is_expiring_soon(client):
    # default expiring_soon_days is 3 (config.py) -- tomorrow falls inside it.
    entry_id = _add_entry(client, best_before_date=date.today() + timedelta(days=1))
    assert _status_of(client, entry_id) == "expiring_soon"


def test_stock_entry_in_the_past_is_expired(client):
    entry_id = _add_entry(client, best_before_date=date.today() - timedelta(days=1))
    assert _status_of(client, entry_id) == "expired"


def test_does_not_spoil_product_is_always_ok(client):
    # #292: shelf-stable goods (rice, canned food) opt out of expiry tracking
    # entirely -- status must stay "ok" even for a best_before_date in the past.
    product = client.post(
        "/api/products", json={"name": "Canned Beans", "does_not_spoil": True}
    ).json()
    assert product["does_not_spoil"] is True
    entry = client.post(
        "/api/stock",
        json={
            "product_id": product["id"],
            "amount": 1,
            "best_before_date": (date.today() - timedelta(days=30)).isoformat(),
        },
    ).json()
    assert _status_of(client, entry["id"]) == "ok"


def test_product_expiring_soon_days_override_takes_precedence_over_global(client):
    # #292: a product can request a tighter/looser expiring-soon window than
    # the household default (config.py default is 3 days).
    product = client.post(
        "/api/products", json={"name": "Fresh Fish", "expiring_soon_days": 10}
    ).json()
    assert product["expiring_soon_days"] == 10
    entry = client.post(
        "/api/stock",
        json={
            "product_id": product["id"],
            "amount": 1,
            "best_before_date": (date.today() + timedelta(days=5)).isoformat(),
        },
    ).json()
    # 5 days out is beyond the global 3-day default, but within the
    # product's own 10-day override.
    assert _status_of(client, entry["id"]) == "expiring_soon"


def test_product_without_expiring_soon_days_override_uses_global_default(client):
    product = client.post(
        "/api/products", json={"name": "Bread"}
    ).json()
    assert product["expiring_soon_days"] is None
    entry = client.post(
        "/api/stock",
        json={
            "product_id": product["id"],
            "amount": 1,
            "best_before_date": (date.today() + timedelta(days=5)).isoformat(),
        },
    ).json()
    # 5 days out is beyond the global 3-day default, and there's no
    # per-product override, so it falls back to "ok".
    assert _status_of(client, entry["id"]) == "ok"


def test_add_stock_rejects_unknown_product(client):
    response = client.post("/api/stock", json={"product_id": 999, "amount": 1})
    assert response.status_code == 404


def test_consume_stock_reduces_amount(client):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    entry = client.post(
        "/api/stock", json={"product_id": product["id"], "amount": 2}
    ).json()

    response = client.post(f"/api/stock/{entry['id']}/consume", json={"amount": 1})
    assert response.status_code == 200
    body = response.json()
    assert body["entry"]["amount"] == 1

    # Consuming the rest fully removes the entry.
    response = client.post(f"/api/stock/{entry['id']}/consume", json={"amount": 1})
    assert response.status_code == 200
    assert response.json()["entry"] is None


def test_consume_stock_rejects_more_than_available(client):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    entry = client.post(
        "/api/stock", json={"product_id": product["id"], "amount": 1}
    ).json()

    response = client.post(f"/api/stock/{entry['id']}/consume", json={"amount": 5})
    assert response.status_code == 422

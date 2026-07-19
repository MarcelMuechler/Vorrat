from datetime import date, timedelta


def _consume(client, amount=1, reason="used"):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    entry = client.post(
        "/api/stock", json={"product_id": product["id"], "amount": amount}
    ).json()
    response = client.post(
        f"/api/stock/{entry['id']}/consume", json={"amount": amount, "reason": reason}
    )
    assert response.status_code == 200
    return product


def test_consuming_stock_writes_a_consumption_log_entry(client):
    product = _consume(client, amount=2, reason="used")

    response = client.get("/api/consumption-log")
    assert response.status_code == 200
    (entry,) = response.json()
    assert entry["product_id"] == product["id"]
    assert entry["product_name"] == "Milk"
    assert entry["amount"] == 2
    assert entry["reason"] == "used"


def test_consumption_log_filters_by_reason(client):
    _consume(client, reason="used")
    _consume(client, reason="spoiled")

    response = client.get("/api/consumption-log", params={"reason": "spoiled"})
    assert response.status_code == 200
    entries = response.json()
    assert len(entries) == 1
    assert entries[0]["reason"] == "spoiled"


def test_consumption_log_filters_by_since_and_until(client):
    _consume(client, reason="used")

    today = date.today()
    # A window that excludes today entirely should return nothing.
    response = client.get(
        "/api/consumption-log",
        params={
            "since": (today - timedelta(days=10)).isoformat(),
            "until": (today - timedelta(days=1)).isoformat(),
        },
    )
    assert response.json() == []

    # A window that includes today should return the entry.
    response = client.get(
        "/api/consumption-log",
        params={
            "since": (today - timedelta(days=1)).isoformat(),
            "until": today.isoformat(),
        },
    )
    assert len(response.json()) == 1


def test_export_consumption_log_csv(client):
    _consume(client, amount=1, reason="used")

    response = client.get("/api/consumption-log/export.csv")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/csv")
    lines = response.text.strip().splitlines()
    assert lines[0] == "created_at,product_name,amount,quantity_unit,reason"
    assert "Milk" in lines[1]
    assert "used" in lines[1]

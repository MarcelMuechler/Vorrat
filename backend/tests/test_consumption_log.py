import os
import time
from datetime import date, datetime, timedelta


def _consume(client, amount=1, reason="used", price=None):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    payload = {"product_id": product["id"], "amount": amount}
    if price is not None:
        payload["price"] = price
    entry = client.post("/api/stock", json=payload).json()
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


def test_local_midnight_utc_converts_local_calendar_day_to_utc(monkeypatch):
    # Regression test for the since/until filters comparing a local calendar
    # date directly against created_at (naive UTC, from SQLite's
    # CURRENT_TIMESTAMP) -- wrong for part of the day whenever the local and
    # UTC calendar dates differ. Forces a specific TZ rather than relying on
    # whatever offset happens to be in effect when the suite runs, so this
    # doesn't depend on wall-clock time like the bug it guards against.
    from app.routers.consumption_log import _local_midnight_utc

    original_tz = os.environ.get("TZ")
    os.environ["TZ"] = "Europe/Berlin"
    time.tzset()
    try:
        # July -> CEST (UTC+2): local midnight July 22 is 22:00 UTC July 21.
        assert _local_midnight_utc(date(2026, 7, 22)) == datetime(2026, 7, 21, 22, 0, 0)
    finally:
        if original_tz is None:
            os.environ.pop("TZ", None)
        else:
            os.environ["TZ"] = original_tz
        time.tzset()


def test_export_consumption_log_csv(client):
    _consume(client, amount=1, reason="used", price=1.25)

    response = client.get("/api/consumption-log/export.csv")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/csv")
    lines = response.text.strip().splitlines()
    # price (#321) rides along, snapshotted at consume time -- without it the
    # export can't answer what the waste was worth.
    assert lines[0] == "created_at,product_name,amount,quantity_unit,reason,price"
    assert "Milk" in lines[1]
    assert "used" in lines[1]
    assert lines[1].endswith(",1.25")


def test_consumption_log_summary_values_used_and_spoiled_separately(client):
    _consume(client, amount=2, reason="used", price=1.5)  # 3.0
    _consume(client, amount=1, reason="spoiled", price=4.0)  # 4.0
    _consume(client, amount=5, reason="spoiled")  # unpriced: counted, adds nothing

    summary = client.get("/api/consumption-log/summary").json()
    assert summary == {
        "used_entries": 1,
        "used_value": 3.0,
        "spoiled_entries": 2,
        "spoiled_value": 4.0,
    }


def test_consumption_log_summary_respects_the_window(client):
    _consume(client, amount=1, reason="spoiled", price=2.0)

    tomorrow = date.today() + timedelta(days=1)
    summary = client.get("/api/consumption-log/summary", params={"since": tomorrow.isoformat()}).json()
    assert summary["spoiled_entries"] == 0
    assert summary["spoiled_value"] == 0.0

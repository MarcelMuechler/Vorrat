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


def test_consumption_log_rows_carry_the_snapshotted_price(client):
    """The history screen values a window by folding `amount * price` over
    these rows (#321), so the per-unit price has to be on each one -- and
    unpriced rows have to arrive as null, not 0, so they count without
    silently valuing themselves at nothing."""
    _consume(client, amount=2, reason="used", price=1.5)
    _consume(client, amount=5, reason="spoiled")

    entries = client.get("/api/consumption-log").json()
    by_reason = {entry["reason"]: entry for entry in entries}
    assert by_reason["used"]["price"] == 1.5
    assert by_reason["used"]["amount"] == 2
    assert by_reason["spoiled"]["price"] is None

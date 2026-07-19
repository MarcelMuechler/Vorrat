from datetime import date, timedelta

from app.config import settings as env_settings


def test_read_settings_seeds_from_env_default(client):
    response = client.get("/api/settings")
    assert response.status_code == 200
    assert response.json() == {"expiring_soon_days": env_settings.expiring_soon_days}


def test_update_settings_persists_and_is_read_back(client):
    response = client.patch("/api/settings", json={"expiring_soon_days": 7})
    assert response.status_code == 200
    assert response.json() == {"expiring_soon_days": 7}

    response = client.get("/api/settings")
    assert response.json() == {"expiring_soon_days": 7}


def test_update_settings_rejects_non_positive_value(client):
    response = client.patch("/api/settings", json={"expiring_soon_days": 0})
    assert response.status_code == 422


def test_updated_expiring_soon_days_affects_stock_status(client):
    # Business-logic edge case: changing the runtime setting must actually
    # shift the ok/expiring_soon boundary used by /api/stock (mirrors
    # test_stock.py's status coverage, but driven through the settings API).
    product = client.post("/api/products", json={"name": "Milk"}).json()
    entry = client.post(
        "/api/stock",
        json={
            "product_id": product["id"],
            "amount": 1,
            "best_before_date": (date.today() + timedelta(days=5)).isoformat(),
        },
    ).json()

    items = client.get("/api/stock").json()
    (item,) = [i for i in items if i["id"] == entry["id"]]
    assert item["status"] == "ok"

    client.patch("/api/settings", json={"expiring_soon_days": 10})

    items = client.get("/api/stock").json()
    (item,) = [i for i in items if i["id"] == entry["id"]]
    assert item["status"] == "expiring_soon"

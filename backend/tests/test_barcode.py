from app.off_client import OffLookupError
from app.routers import barcode as barcode_router


def test_lookup_barcode_hits_local_product(client):
    client.post("/api/products", json={"name": "Milk", "barcode": "1234567890123"})

    response = client.get("/api/barcode/1234567890123")
    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "local"
    assert body["product"]["name"] == "Milk"


def test_lookup_barcode_hits_local_product_via_extra_barcode(client):
    product = client.post("/api/products", json={"name": "Milk", "barcode": "1234567890123"}).json()
    client.post(f"/api/products/{product['id']}/barcodes", json={"code": "9999999999999"})

    response = client.get("/api/barcode/9999999999999")
    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "local"
    assert body["product"]["id"] == product["id"]


def test_lookup_barcode_falls_back_to_off_when_found(client, monkeypatch):
    async def fake_lookup_off(code):
        assert code == "5000000000000"
        return {
            "barcode": code,
            "name": "OFF Product",
            "category": None,
            "image_url": None,
            "amount": None,
            "quantity_unit": None,
        }

    monkeypatch.setattr(barcode_router, "lookup_off", fake_lookup_off)

    response = client.get("/api/barcode/5000000000000")
    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "off"
    assert body["product"]["name"] == "OFF Product"


def test_lookup_barcode_returns_404_when_off_lookup_genuinely_misses(client, monkeypatch):
    # A clean miss (OFF answered, no matching product) comes back as None --
    # that's a real "not found", distinct from OffLookupError below.
    async def fake_lookup_off(code):
        return None

    monkeypatch.setattr(barcode_router, "lookup_off", fake_lookup_off)

    response = client.get("/api/barcode/0000000000000")
    assert response.status_code == 404


def test_lookup_barcode_returns_503_when_off_is_unreachable(client, monkeypatch):
    # OffLookupError means OFF couldn't be reached/answered at all (timeout,
    # connection failure, repeated 5xx/429) -- must surface as a distinct
    # 503, not be folded into the same 404 "not found" as a genuine miss.
    async def fake_lookup_off(code):
        raise OffLookupError("simulated network failure")

    monkeypatch.setattr(barcode_router, "lookup_off", fake_lookup_off)

    response = client.get("/api/barcode/0000000000001")
    assert response.status_code == 503

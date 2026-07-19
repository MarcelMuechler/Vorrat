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


def test_lookup_barcode_returns_404_when_off_lookup_misses_or_errors(client, monkeypatch):
    # lookup_off never raises -- a network error or genuine miss both come
    # back as None (see off_client.py's docstring) -- so the router's 404
    # path only needs to be exercised against that single return value.
    async def fake_lookup_off(code):
        return None

    monkeypatch.setattr(barcode_router, "lookup_off", fake_lookup_off)

    response = client.get("/api/barcode/0000000000000")
    assert response.status_code == 404

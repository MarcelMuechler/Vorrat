def test_create_and_get_product(client):
    response = client.post("/api/products", json={"name": "Milk", "barcode": "1234567890123"})
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Milk"
    assert body["barcode"] == "1234567890123"
    assert body["extra_barcodes"] == []

    response = client.get(f"/api/products/{body['id']}")
    assert response.status_code == 200
    assert response.json()["name"] == "Milk"


def test_get_product_not_found(client):
    response = client.get("/api/products/999")
    assert response.status_code == 404


def test_create_product_rejects_duplicate_barcode(client):
    client.post("/api/products", json={"name": "Milk", "barcode": "1234567890123"})
    response = client.post("/api/products", json={"name": "Milk 2", "barcode": "1234567890123"})
    assert response.status_code == 409


def test_list_products_search(client):
    client.post("/api/products", json={"name": "Whole Milk"})
    client.post("/api/products", json={"name": "Orange Juice"})

    response = client.get("/api/products", params={"search": "milk"})
    assert response.status_code == 200
    names = [p["name"] for p in response.json()]
    assert names == ["Whole Milk"]


def test_update_product(client):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    response = client.patch(f"/api/products/{product['id']}", json={"name": "Oat Milk"})
    assert response.status_code == 200
    assert response.json()["name"] == "Oat Milk"


def test_update_product_not_found(client):
    response = client.patch("/api/products/999", json={"name": "Oat Milk"})
    assert response.status_code == 404


def test_delete_product(client):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    response = client.delete(f"/api/products/{product['id']}")
    assert response.status_code == 204
    assert client.get(f"/api/products/{product['id']}").status_code == 404


def test_delete_product_blocked_by_stock(client):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    client.post("/api/stock", json={"product_id": product["id"], "amount": 1})

    response = client.delete(f"/api/products/{product['id']}")
    assert response.status_code == 409

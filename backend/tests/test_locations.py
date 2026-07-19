def test_create_and_list_location(client):
    response = client.post("/api/locations", json={"name": "Fridge"})
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Fridge"
    assert "id" in body

    response = client.get("/api/locations")
    assert response.status_code == 200
    assert [loc["name"] for loc in response.json()] == ["Fridge"]


def test_create_location_rejects_blank_name(client):
    response = client.post("/api/locations", json={"name": "   "})
    assert response.status_code == 422


def test_create_location_rejects_case_insensitive_duplicate(client):
    assert client.post("/api/locations", json={"name": "Fridge"}).status_code == 201
    response = client.post("/api/locations", json={"name": "fridge"})
    assert response.status_code == 409


def test_update_location_rejects_duplicate_name(client):
    client.post("/api/locations", json={"name": "Fridge"})
    cellar = client.post("/api/locations", json={"name": "Cellar"}).json()

    response = client.patch(f"/api/locations/{cellar['id']}", json={"name": "FRIDGE"})
    assert response.status_code == 409


def test_delete_location_not_found(client):
    response = client.delete("/api/locations/999")
    assert response.status_code == 404


def test_delete_location_blocked_by_stock(client):
    location = client.post("/api/locations", json={"name": "Fridge"}).json()
    product = client.post("/api/products", json={"name": "Milk"}).json()
    client.post(
        "/api/stock",
        json={"product_id": product["id"], "location_id": location["id"], "amount": 1},
    )

    response = client.delete(f"/api/locations/{location['id']}")
    assert response.status_code == 409

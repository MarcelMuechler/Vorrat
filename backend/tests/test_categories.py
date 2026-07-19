def test_create_and_list_categories(client):
    response = client.post("/api/categories", json={"name": "Dairy"})
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Dairy"

    client.post("/api/categories", json={"name": "Bakery"})

    response = client.get("/api/categories")
    assert response.status_code == 200
    # Ordered by name.
    assert [c["name"] for c in response.json()] == ["Bakery", "Dairy"]


def test_create_category_rejects_case_insensitive_duplicate(client):
    client.post("/api/categories", json={"name": "Dairy"})
    response = client.post("/api/categories", json={"name": "dairy"})
    assert response.status_code == 409


def test_update_category(client):
    category = client.post("/api/categories", json={"name": "Dairy"}).json()
    response = client.patch(f"/api/categories/{category['id']}", json={"name": "Milk Products"})
    assert response.status_code == 200
    assert response.json()["name"] == "Milk Products"


def test_update_category_not_found(client):
    response = client.patch("/api/categories/999", json={"name": "Dairy"})
    assert response.status_code == 404


def test_update_category_rejects_case_insensitive_duplicate(client):
    client.post("/api/categories", json={"name": "Dairy"})
    other = client.post("/api/categories", json={"name": "Bakery"}).json()

    response = client.patch(f"/api/categories/{other['id']}", json={"name": "dairy"})
    assert response.status_code == 409


def test_delete_category_clears_product_category_id(client):
    category = client.post("/api/categories", json={"name": "Dairy"}).json()
    product = client.post(
        "/api/products", json={"name": "Milk", "category_id": category["id"]}
    ).json()
    assert product["category_id"] == category["id"]

    response = client.delete(f"/api/categories/{category['id']}")
    assert response.status_code == 204

    # Unlike a Location, deleting a Category doesn't block on products still
    # using it -- it just clears their category_id (#72).
    updated = client.get(f"/api/products/{product['id']}").json()
    assert updated["category_id"] is None


def test_delete_category_not_found(client):
    response = client.delete("/api/categories/999")
    assert response.status_code == 404

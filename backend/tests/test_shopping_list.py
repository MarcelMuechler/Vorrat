def test_create_and_list_free_text_item(client):
    response = client.post("/api/shopping-list", json={"name": "Candles", "amount": 2})
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Candles"
    assert body["product_id"] is None
    assert body["done"] is False

    response = client.get("/api/shopping-list")
    assert response.status_code == 200
    assert [i["name"] for i in response.json()] == ["Candles"]


def test_create_item_requires_product_or_name(client):
    response = client.post("/api/shopping-list", json={"amount": 1})
    assert response.status_code == 422


def test_create_item_linked_to_product_falls_back_to_product_name_and_unit(client):
    product = client.post(
        "/api/products", json={"name": "Milk", "quantity_unit": "l"}
    ).json()
    response = client.post("/api/shopping-list", json={"product_id": product["id"]})
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Milk"
    assert body["unit"] == "l"


def test_create_item_rejects_unknown_product(client):
    response = client.post("/api/shopping-list", json={"product_id": 999})
    assert response.status_code == 404


def test_create_item_rejects_category_on_product_linked_item(client):
    category = client.post("/api/categories", json={"name": "Dairy"}).json()
    product = client.post("/api/products", json={"name": "Milk"}).json()
    response = client.post(
        "/api/shopping-list",
        json={"product_id": product["id"], "category_id": category["id"]},
    )
    assert response.status_code == 422


def test_update_item_toggle_done(client):
    item = client.post("/api/shopping-list", json={"name": "Candles"}).json()
    response = client.patch(f"/api/shopping-list/{item['id']}", json={"done": True})
    assert response.status_code == 200
    assert response.json()["done"] is True


def test_update_item_not_found(client):
    response = client.patch("/api/shopping-list/999", json={"done": True})
    assert response.status_code == 404


def test_update_item_rejects_dropping_both_product_and_name(client):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    item = client.post("/api/shopping-list", json={"product_id": product["id"]}).json()

    # Clearing product_id without ever having a name set must fail -- it
    # would otherwise leave the item with neither identity.
    response = client.patch(
        f"/api/shopping-list/{item['id']}", json={"product_id": None}
    )
    assert response.status_code == 422


def test_delete_item(client):
    item = client.post("/api/shopping-list", json={"name": "Candles"}).json()
    response = client.delete(f"/api/shopping-list/{item['id']}")
    assert response.status_code == 204
    assert client.get("/api/shopping-list").json() == []


def test_delete_item_not_found(client):
    response = client.delete("/api/shopping-list/999")
    assert response.status_code == 404


def test_clear_done_items_only_deletes_done(client):
    todo = client.post("/api/shopping-list", json={"name": "Candles"}).json()
    done = client.post("/api/shopping-list", json={"name": "Balloons"}).json()
    client.patch(f"/api/shopping-list/{done['id']}", json={"done": True})

    response = client.delete("/api/shopping-list/done")
    assert response.status_code == 200
    assert response.json() == {"deleted": 1}

    remaining = client.get("/api/shopping-list").json()
    assert [i["id"] for i in remaining] == [todo["id"]]


def test_add_low_stock_items_uses_target_stock_level_deficit(client):
    product = client.post(
        "/api/products",
        json={"name": "Flour", "low_stock_threshold": 2, "target_stock_level": 5},
    ).json()
    client.post("/api/stock", json={"product_id": product["id"], "amount": 1})

    response = client.post("/api/shopping-list/add-low-stock")
    assert response.status_code == 200
    (item,) = response.json()
    assert item["product_id"] == product["id"]
    # target_stock_level (5) - current stock (1) = 4.
    assert item["amount"] == 4


def test_add_low_stock_items_defaults_to_one_without_target_level(client):
    product = client.post(
        "/api/products", json={"name": "Flour", "low_stock_threshold": 2}
    ).json()
    client.post("/api/stock", json={"product_id": product["id"], "amount": 1})

    response = client.post("/api/shopping-list/add-low-stock")
    (item,) = response.json()
    assert item["amount"] == 1


def test_add_low_stock_items_is_a_no_op_when_already_queued(client):
    product = client.post(
        "/api/products", json={"name": "Flour", "low_stock_threshold": 2}
    ).json()
    client.post("/api/stock", json={"product_id": product["id"], "amount": 1})

    first = client.post("/api/shopping-list/add-low-stock")
    assert len(first.json()) == 1

    second = client.post("/api/shopping-list/add-low-stock")
    assert second.json() == []

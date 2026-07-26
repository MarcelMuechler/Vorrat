"""Bulk stock actions and server-authoritative undo.

Ported from smoke_test.sh, which was the only coverage for these routes.
"""


def _product(client, name, **kwargs):
    return client.post("/api/products", json={"name": name, **kwargs}).json()


def _entry(client, product_id, amount=1, **kwargs):
    return client.post(
        "/api/stock", json={"product_id": product_id, "amount": amount, **kwargs}
    ).json()


def test_bulk_consume_removes_every_listed_entry(client):
    product = _product(client, "Milk")
    ids = [_entry(client, product["id"], 2)["id"] for _ in range(3)]

    response = client.post("/api/stock/bulk/consume", json={"entry_ids": ids})
    assert response.status_code == 200
    assert response.json()["consumed"] == 3
    assert client.get(f"/api/stock?product_id={product['id']}").json() == []


def test_bulk_delete_removes_every_listed_entry(client):
    product = _product(client, "Milk")
    ids = [_entry(client, product["id"], 2)["id"] for _ in range(2)]

    response = client.post("/api/stock/bulk/delete", json={"entry_ids": ids})
    assert response.status_code == 200
    assert response.json()["deleted"] == 2
    assert client.get(f"/api/stock?product_id={product['id']}").json() == []


def test_bulk_delete_logs_the_removed_amount_as_spoiled(client):
    product = _product(client, "Milk")
    entry = _entry(client, product["id"], 3)

    client.post("/api/stock/bulk/delete", json={"entry_ids": [entry["id"]]})

    (log,) = client.get("/api/consumption-log").json()
    assert log["reason"] == "spoiled"
    assert log["amount"] == 3


def test_bulk_move_relocates_every_listed_entry(client):
    product = _product(client, "Milk")
    location = client.post("/api/locations", json={"name": "Cellar"}).json()
    ids = [_entry(client, product["id"], 1)["id"] for _ in range(2)]

    response = client.post(
        "/api/stock/bulk/move", json={"entry_ids": ids, "location_id": location["id"]}
    )
    assert response.status_code == 200
    assert response.json()["moved"] == 2
    assert all(i["location_id"] == location["id"] for i in response.json()["entries"])


def test_bulk_move_rejects_unknown_location(client):
    product = _product(client, "Milk")
    entry = _entry(client, product["id"])

    response = client.post(
        "/api/stock/bulk/move", json={"entry_ids": [entry["id"]], "location_id": 999999}
    )
    assert response.status_code == 404


def test_bulk_action_with_one_unknown_id_changes_nothing(client):
    """All-or-nothing: the 404 must land before any mutation happens."""
    product = _product(client, "Milk")
    entry = _entry(client, product["id"], 5)

    response = client.post(
        "/api/stock/bulk/consume", json={"entry_ids": [entry["id"], 999999]}
    )
    assert response.status_code == 404

    (still_there,) = client.get(f"/api/stock?product_id={product['id']}").json()
    assert still_there["amount"] == 5


def test_bulk_routes_are_not_shadowed_by_the_entry_id_route(client):
    """/bulk/consume must not be matched by /{entry_id}/consume and 422 on
    parsing "bulk" as an int -- route registration order guards this."""
    response = client.post("/api/stock/bulk/consume", json={"entry_ids": [999999]})
    assert response.status_code == 404  # not 422


def test_undo_restores_the_snapshot_and_ignores_a_tampering_body(client):
    """The #224 reproduction: try to erase one product's log while
    fabricating stock for another. Undo must restore exactly what was
    consumed and never the client-supplied values."""
    location = client.post("/api/locations", json={"name": "Fridge"}).json()
    real = _product(client, "Real Product")
    decoy = _product(client, "Decoy Product")
    entry = _entry(client, real["id"], 4, location_id=location["id"])

    log_id = client.post(
        f"/api/stock/{entry['id']}/consume", json={"amount": 4}
    ).json()["consumption_log_id"]

    response = client.post(
        f"/api/stock/undo/{log_id}", json={"product_id": decoy["id"], "amount": 999}
    )
    assert response.status_code == 201
    restored = response.json()
    assert restored["amount"] == 4
    assert restored["product_id"] == real["id"]
    assert restored["location_id"] == location["id"]

    assert client.get(f"/api/stock?product_id={decoy['id']}").json() == []
    assert len(client.get(f"/api/stock?product_id={real['id']}").json()) == 1


def test_undo_deletes_the_log_row_so_stats_are_not_overstated(client):
    product = _product(client, "Milk")
    entry = _entry(client, product["id"], 2)
    log_id = client.post(
        f"/api/stock/{entry['id']}/consume", json={"amount": 2}
    ).json()["consumption_log_id"]

    client.post(f"/api/stock/undo/{log_id}")

    assert [x for x in client.get("/api/consumption-log").json() if x["id"] == log_id] == []


def test_undo_is_one_shot(client):
    product = _product(client, "Milk")
    entry = _entry(client, product["id"], 2)
    log_id = client.post(
        f"/api/stock/{entry['id']}/consume", json={"amount": 2}
    ).json()["consumption_log_id"]

    assert client.post(f"/api/stock/undo/{log_id}").status_code == 201
    assert client.post(f"/api/stock/undo/{log_id}").status_code == 404


def test_undo_unknown_log_id_creates_nothing(client):
    product = _product(client, "Milk")
    _entry(client, product["id"], 1)
    before = client.get(f"/api/stock?product_id={product['id']}").json()

    assert client.post("/api/stock/undo/999999").status_code == 404
    assert client.get(f"/api/stock?product_id={product['id']}").json() == before


def test_bulk_consume_log_is_not_undoable(client):
    """Bulk actions never offered Undo; their log rows carry no snapshot and
    must be rejected rather than reconstructed from a client body (#224)."""
    product = _product(client, "Bulk Consumed")
    entry = _entry(client, product["id"], 2)
    client.post("/api/stock/bulk/consume", json={"entry_ids": [entry["id"]]})

    (log,) = client.get("/api/consumption-log").json()
    response = client.post(
        f"/api/stock/undo/{log['id']}", json={"product_id": product["id"], "amount": 999}
    )
    assert response.status_code == 409

    assert client.get(f"/api/stock?product_id={product['id']}").json() == []
    assert len(client.get("/api/consumption-log").json()) == 1

"""Stock list filtering, ordering, pagination, and effective expiry (#225).

Ported from smoke_test.sh, which was the only coverage for these.
"""

from datetime import date, timedelta


def _product(client, name, **kwargs):
    return client.post("/api/products", json={"name": name, **kwargs}).json()


def _entry(client, product_id, amount=1, **kwargs):
    return client.post(
        "/api/stock", json={"product_id": product_id, "amount": amount, **kwargs}
    ).json()


def test_filter_by_product(client):
    milk = _product(client, "Milk")
    bread = _product(client, "Bread")
    _entry(client, milk["id"])
    _entry(client, bread["id"])

    items = client.get(f"/api/stock?product_id={milk['id']}").json()
    assert [i["product_name"] for i in items] == ["Milk"]


def test_filter_by_location(client):
    product = _product(client, "Milk")
    fridge = client.post("/api/locations", json={"name": "Fridge"}).json()
    _entry(client, product["id"], location_id=fridge["id"])
    _entry(client, product["id"])

    items = client.get(f"/api/stock?location_id={fridge['id']}").json()
    assert len(items) == 1
    assert items[0]["location_name"] == "Fridge"


def test_filter_by_category(client):
    dairy = client.post("/api/categories", json={"name": "Dairy"}).json()
    milk = _product(client, "Milk", category_id=dairy["id"])
    bread = _product(client, "Bread")
    _entry(client, milk["id"])
    _entry(client, bread["id"])

    items = client.get(f"/api/stock?category_id={dairy['id']}").json()
    assert [i["product_name"] for i in items] == ["Milk"]


def test_search_matches_product_name_case_insensitively(client):
    milk = _product(client, "Milk")
    _product(client, "Bread")
    _entry(client, milk["id"])

    assert len(client.get("/api/stock?search=mil").json()) == 1
    assert client.get("/api/stock?search=zzz").json() == []


def test_search_treats_like_wildcards_literally(client):
    weird = _product(client, "100% Juice")
    plain = _product(client, "Milk")
    _entry(client, weird["id"])
    _entry(client, plain["id"])

    items = client.get("/api/stock?search=100%25").json()
    assert [i["product_name"] for i in items] == ["100% Juice"]


def test_expiring_within_days_filter(client):
    product = _product(client, "Milk")
    _entry(client, product["id"], best_before_date=(date.today() + timedelta(days=2)).isoformat())
    _entry(client, product["id"], best_before_date=(date.today() + timedelta(days=60)).isoformat())

    items = client.get("/api/stock?expiring_within_days=7").json()
    assert len(items) == 1


def test_expiring_within_days_sees_an_opened_entry_with_no_best_before_date(client):
    """#225: effective expiry is opened_at + the product's open shelf life,
    so an opened entry with no BBD must not be invisible to this filter."""
    product = _product(client, "Opened Milk", default_open_shelf_life_days=3)
    entry = _entry(client, product["id"])
    client.patch(f"/api/stock/{entry['id']}", json={"opened_at": date.today().isoformat()})

    items = client.get("/api/stock?expiring_within_days=7").json()
    assert len(items) == 1
    assert items[0]["effective_expiry_date"] == (date.today() + timedelta(days=3)).isoformat()


def test_effective_expiry_is_the_earlier_of_bbd_and_open_shelf_life(client):
    product = _product(client, "Milk", default_open_shelf_life_days=2)
    entry = _entry(
        client, product["id"], best_before_date=(date.today() + timedelta(days=30)).isoformat()
    )
    client.patch(f"/api/stock/{entry['id']}", json={"opened_at": date.today().isoformat()})

    (item,) = client.get("/api/stock").json()
    assert item["effective_expiry_date"] == (date.today() + timedelta(days=2)).isoformat()


def test_default_order_is_by_effective_expiry_with_nulls_last(client):
    product = _product(client, "Milk")
    _entry(client, product["id"], amount=1)  # no date
    _entry(client, product["id"], amount=2, best_before_date=(date.today() + timedelta(days=30)).isoformat())
    _entry(client, product["id"], amount=3, best_before_date=(date.today() + timedelta(days=1)).isoformat())

    amounts = [i["amount"] for i in client.get("/api/stock").json()]
    assert amounts == [3, 2, 1]


def test_limit_and_offset_paginate_stably(client):
    product = _product(client, "Milk")
    for days in (1, 2, 3, 4):
        _entry(
            client,
            product["id"],
            amount=days,
            best_before_date=(date.today() + timedelta(days=days)).isoformat(),
        )

    first = client.get("/api/stock?limit=2").json()
    second = client.get("/api/stock?limit=2&offset=2").json()
    assert [i["amount"] for i in first] == [1, 2]
    assert [i["amount"] for i in second] == [3, 4]


def test_limit_is_bounded(client):
    assert client.get("/api/stock?limit=0").status_code == 422
    assert client.get("/api/stock?limit=1001").status_code == 422
    assert client.get("/api/stock?offset=-1").status_code == 422


def test_patch_stock_rejects_unknown_location(client):
    product = _product(client, "Milk")
    entry = _entry(client, product["id"])
    assert client.patch(f"/api/stock/{entry['id']}", json={"location_id": 999999}).status_code == 404


def test_patch_stock_not_found(client):
    assert client.patch("/api/stock/999999", json={"amount": 1}).status_code == 404


# The #228 Infinity/NaN rejection stays in smoke_test.sh: the schema rejects
# it correctly here too, but TestClient re-raises the resulting encoder error
# instead of returning the 422 a real server responds with, so only a live
# server actually exercises the behavior clients see.

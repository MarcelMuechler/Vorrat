"""Alternate product barcodes (#208, #223) and product photo upload (#210).

Ported from smoke_test.sh, which was the only coverage for these routes.
"""

import base64

# Smallest valid PNG (1x1), inline so this has no fixture-file dependency.
PNG_BYTES = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGP4z8AARwgWXg4A"
    "rpMP8aaUSCMAAAAASUVORK5CYII="
)


def _product(client, name, **kwargs):
    return client.post("/api/products", json={"name": name, **kwargs}).json()


def test_add_alternate_barcode_resolves_via_lookup(client):
    product = _product(client, "Milk", barcode="111")

    response = client.post(f"/api/products/{product['id']}/barcodes", json={"code": "222"})
    assert response.status_code == 201
    assert response.json()["extra_barcodes"] == ["222"]

    lookup = client.get("/api/barcode/222").json()
    assert lookup["source"] == "local"
    assert lookup["product"]["id"] == product["id"]


def test_alternate_barcode_is_normalized(client):
    product = _product(client, "Milk")
    client.post(f"/api/products/{product['id']}/barcodes", json={"code": "  333  "})
    assert client.get(f"/api/products/{product['id']}").json()["extra_barcodes"] == ["333"]


def test_remove_alternate_barcode(client):
    product = _product(client, "Milk")
    client.post(f"/api/products/{product['id']}/barcodes", json={"code": "222"})

    response = client.delete(f"/api/products/{product['id']}/barcodes/222")
    assert response.status_code == 200
    assert response.json()["extra_barcodes"] == []


def test_remove_unknown_alternate_barcode_is_404(client):
    product = _product(client, "Milk")
    assert client.delete(f"/api/products/{product['id']}/barcodes/999").status_code == 404


def test_alternate_barcode_cannot_collide_with_a_primary_barcode(client):
    """One global namespace (#223) -- otherwise barcode.py's primary-first
    lookup would silently shadow the alternate."""
    _product(client, "Milk", barcode="111")
    other = _product(client, "Bread")

    response = client.post(f"/api/products/{other['id']}/barcodes", json={"code": "111"})
    assert response.status_code == 409


def test_alternate_barcode_cannot_collide_with_another_products_alternate(client):
    first = _product(client, "Milk")
    second = _product(client, "Bread")
    client.post(f"/api/products/{first['id']}/barcodes", json={"code": "222"})

    response = client.post(f"/api/products/{second['id']}/barcodes", json={"code": "222"})
    assert response.status_code == 409


def test_primary_barcode_cannot_collide_with_an_existing_alternate(client):
    first = _product(client, "Milk")
    client.post(f"/api/products/{first['id']}/barcodes", json={"code": "222"})

    response = client.post("/api/products", json={"name": "Bread", "barcode": "222"})
    assert response.status_code == 409


def test_upload_image_sets_image_url_under_uploads(client):
    product = _product(client, "Milk")

    response = client.post(
        f"/api/products/{product['id']}/image",
        files={"file": ("photo.png", PNG_BYTES, "image/png")},
    )
    assert response.status_code == 200
    assert response.json()["image_url"].startswith("/uploads/")


def test_reupload_replaces_the_url_and_removes_the_old_file(client, tmp_path):
    product = _product(client, "Milk")
    first = client.post(
        f"/api/products/{product['id']}/image",
        files={"file": ("photo.png", PNG_BYTES, "image/png")},
    ).json()["image_url"]

    second = client.post(
        f"/api/products/{product['id']}/image",
        files={"file": ("photo.png", PNG_BYTES, "image/png")},
    ).json()["image_url"]

    assert second != first
    uploads = tmp_path / "uploads"
    assert not (uploads / first.removeprefix("/uploads/")).exists()
    assert (uploads / second.removeprefix("/uploads/")).exists()


def test_upload_rejects_a_non_image_content_type(client):
    product = _product(client, "Milk")
    response = client.post(
        f"/api/products/{product['id']}/image",
        files={"file": ("notes.txt", b"not an image", "text/plain")},
    )
    assert response.status_code == 415


def test_upload_rejects_an_empty_file(client):
    product = _product(client, "Milk")
    response = client.post(
        f"/api/products/{product['id']}/image",
        files={"file": ("photo.png", b"", "image/png")},
    )
    assert response.status_code == 422


def test_upload_rejects_an_oversized_image(client):
    from app.routers.products import _MAX_IMAGE_BYTES

    product = _product(client, "Milk")
    response = client.post(
        f"/api/products/{product['id']}/image",
        files={"file": ("photo.png", b"x" * (_MAX_IMAGE_BYTES + 1), "image/png")},
    )
    assert response.status_code == 413


def test_upload_to_unknown_product_is_404(client):
    response = client.post(
        "/api/products/999999/image", files={"file": ("photo.png", PNG_BYTES, "image/png")}
    )
    assert response.status_code == 404


def test_deleting_a_product_removes_its_uploaded_photo(client, tmp_path):
    product = _product(client, "Milk")
    image_url = client.post(
        f"/api/products/{product['id']}/image",
        files={"file": ("photo.png", PNG_BYTES, "image/png")},
    ).json()["image_url"]

    client.delete(f"/api/products/{product['id']}")

    assert not (tmp_path / "uploads" / image_url.removeprefix("/uploads/")).exists()

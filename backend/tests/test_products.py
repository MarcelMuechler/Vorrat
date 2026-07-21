import socket


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


def test_create_product_defaults_does_not_spoil_false_and_no_expiring_soon_override(client):
    response = client.post("/api/products", json={"name": "Milk"})
    body = response.json()
    assert body["does_not_spoil"] is False
    assert body["expiring_soon_days"] is None


def test_create_product_rejects_non_positive_expiring_soon_days(client):
    response = client.post(
        "/api/products", json={"name": "Milk", "expiring_soon_days": 0}
    )
    assert response.status_code == 422


def test_update_product_sets_does_not_spoil_and_expiring_soon_days(client):
    product = client.post("/api/products", json={"name": "Rice"}).json()
    response = client.patch(
        f"/api/products/{product['id']}",
        json={"does_not_spoil": True, "expiring_soon_days": 14},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["does_not_spoil"] is True
    assert body["expiring_soon_days"] == 14


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


def test_update_product_with_uploads_path_traversal_image_url_does_not_delete_outside_uploads_dir(
    client, tmp_path
):
    # image_url has no format restriction (it must also accept arbitrary
    # pasted external URLs), so a malicious/typo'd value can look like a
    # path-traversal attempt out of UPLOADS_DIR. The canary file below sits
    # one level above UPLOADS_DIR -- exactly where "/uploads/../canary.db"
    # would resolve to -- and must survive both requests below.
    from app.routers import products as products_router

    canary = products_router.UPLOADS_DIR.parent / "canary.db"
    canary.write_text("do not delete me")

    product = client.post("/api/products", json={"name": "Milk"}).json()
    # First PATCH plants the traversal path as this product's "previously
    # uploaded" image so the second PATCH's cleanup-of-the-old-value has
    # something to try to delete.
    client.patch(f"/api/products/{product['id']}", json={"image_url": "/uploads/../canary.db"})
    client.patch(f"/api/products/{product['id']}", json={"image_url": "/uploads/legit.jpg"})

    assert canary.read_text() == "do not delete me"


def test_update_product_cleans_up_previously_uploaded_image_when_replaced(client):
    product = client.post("/api/products", json={"name": "Milk"}).json()
    upload = client.post(
        f"/api/products/{product['id']}/image",
        files={"file": ("photo.png", b"\x89PNG\r\n\x1a\n" + b"0" * 16, "image/png")},
    )
    old_url = upload.json()["image_url"]
    assert old_url.startswith("/uploads/")

    from app.routers import products as products_router

    old_path = products_router.UPLOADS_DIR / old_url.removeprefix("/uploads/")
    assert old_path.exists()

    client.patch(f"/api/products/{product['id']}", json={"image_url": "https://example.invalid/no-such-host.jpg"})

    assert not old_path.exists()


class _FakeStreamResponse:
    """Stands in for httpx.stream()'s context-manager response."""

    def __init__(self, content_type, chunks, is_redirect=False, headers=None):
        self.headers = headers if headers is not None else {"content-type": content_type}
        self._chunks = chunks
        self.is_redirect = is_redirect

    def raise_for_status(self):
        pass

    def iter_bytes(self):
        yield from self._chunks

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def test_cache_remote_image_aborts_without_buffering_past_the_size_cap(monkeypatch, tmp_path):
    # _cache_remote_image must not rely on the response's (possibly
    # absent/lying) Content-Length header to bound memory use -- it has to
    # actually stop reading once the streamed body itself exceeds the cap.
    from app.routers import products as products_router

    monkeypatch.setattr(products_router, "UPLOADS_DIR", tmp_path)
    # This test is about the streaming/size-cap behavior, not the SSRF host
    # check (that has its own tests below) -- skip host resolution so a
    # sandboxed/offline test run doesn't hinge on how "example.invalid"
    # happens to resolve (or fail to).
    monkeypatch.setattr(products_router, "_assert_public_host", lambda url: None)
    oversized_chunk = b"x" * (products_router._MAX_IMAGE_BYTES + 1)
    monkeypatch.setattr(
        products_router.httpx,
        "stream",
        lambda *args, **kwargs: _FakeStreamResponse("image/png", [oversized_chunk]),
    )

    result = products_router._cache_remote_image("https://example.invalid/big.png", product_id=1)

    assert result is None
    assert list(tmp_path.iterdir()) == []


def _stream_never_called(*args, **kwargs):
    raise AssertionError("must not make an outbound request to a non-public host")


def test_cache_remote_image_rejects_loopback_ip_literal(monkeypatch, tmp_path):
    from app.routers import products as products_router

    monkeypatch.setattr(products_router, "UPLOADS_DIR", tmp_path)
    monkeypatch.setattr(products_router.httpx, "stream", _stream_never_called)

    result = products_router._cache_remote_image("http://127.0.0.1/secret.png", product_id=1)

    assert result is None
    assert list(tmp_path.iterdir()) == []


def test_cache_remote_image_rejects_link_local_metadata_ip_literal(monkeypatch, tmp_path):
    from app.routers import products as products_router

    monkeypatch.setattr(products_router, "UPLOADS_DIR", tmp_path)
    monkeypatch.setattr(products_router.httpx, "stream", _stream_never_called)

    result = products_router._cache_remote_image(
        "http://169.254.169.254/latest/meta-data/", product_id=1
    )

    assert result is None
    assert list(tmp_path.iterdir()) == []


def test_cache_remote_image_rejects_private_rfc1918_ip_literal(monkeypatch, tmp_path):
    from app.routers import products as products_router

    monkeypatch.setattr(products_router, "UPLOADS_DIR", tmp_path)
    monkeypatch.setattr(products_router.httpx, "stream", _stream_never_called)

    result = products_router._cache_remote_image("http://10.1.2.3/nas-admin.png", product_id=1)

    assert result is None
    assert list(tmp_path.iterdir()) == []


def test_cache_remote_image_rejects_redirect_to_a_private_ip(monkeypatch, tmp_path):
    # follow_redirects would otherwise let a first hop to an innocuous
    # public-resolving host redirect on to an internal target and bypass an
    # initial-URL-only host check (#288) -- the host must be rechecked after
    # every hop, not just before the first request.
    from app.routers import products as products_router

    monkeypatch.setattr(products_router, "UPLOADS_DIR", tmp_path)

    def fake_getaddrinfo(host, *args, **kwargs):
        ip = "1.1.1.1" if host == "safe.example.invalid" else "127.0.0.1"
        return [(socket.AF_INET, socket.SOCK_STREAM, 6, "", (ip, 0))]

    monkeypatch.setattr(products_router.socket, "getaddrinfo", fake_getaddrinfo)

    calls = {"n": 0}

    def fake_stream(method, url, **kwargs):
        calls["n"] += 1
        if calls["n"] == 1:
            return _FakeStreamResponse(
                "", [], is_redirect=True, headers={"location": "http://internal.example.invalid/secret"}
            )
        raise AssertionError("must not follow a redirect to a private-resolving host")

    monkeypatch.setattr(products_router.httpx, "stream", fake_stream)

    result = products_router._cache_remote_image(
        "http://safe.example.invalid/photo.jpg", product_id=1
    )

    assert result is None
    assert calls["n"] == 1
    assert list(tmp_path.iterdir()) == []


def test_cache_remote_image_still_caches_a_normal_public_image(monkeypatch, tmp_path):
    # The happy path must keep working: a public-resolving host, no
    # redirects, an allowed content-type -- still gets fetched and saved.
    from app.routers import products as products_router

    monkeypatch.setattr(products_router, "UPLOADS_DIR", tmp_path)
    monkeypatch.setattr(
        products_router.socket,
        "getaddrinfo",
        lambda host, *a, **k: [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("1.1.1.1", 0))],
    )
    monkeypatch.setattr(
        products_router.httpx,
        "stream",
        lambda *args, **kwargs: _FakeStreamResponse("image/png", [b"\x89PNG\r\n\x1a\n" + b"0" * 16]),
    )

    result = products_router._cache_remote_image("https://cdn.example.invalid/photo.png", product_id=1)

    assert result is not None
    assert result.startswith("/uploads/")
    saved = tmp_path / result.removeprefix("/uploads/")
    assert saved.exists()


def test_refresh_product_from_off_returns_503_when_off_is_unreachable(client, monkeypatch):
    from app.off_client import OffLookupError
    from app.routers import products as products_router

    product = client.post("/api/products", json={"name": "Milk", "barcode": "1234567890123"}).json()

    async def fake_lookup_off(code):
        raise OffLookupError("simulated network failure")

    monkeypatch.setattr(products_router, "lookup_off", fake_lookup_off)

    response = client.post(f"/api/products/{product['id']}/refresh-from-off")
    assert response.status_code == 503

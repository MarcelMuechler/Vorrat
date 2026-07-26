"""Open Food Facts client: cache behavior and the retry/error contract.

Moved here from off_client.py's own `if __name__ == "__main__":` block, which
only ran if someone remembered to invoke the module directly and so never ran
in CI.
"""

import asyncio

import httpx
import pytest

from app import off_client
from app.off_client import _ERROR, _MAX_ATTEMPTS, OffLookupError


@pytest.fixture(autouse=True)
def _isolated_cache_and_no_backoff(monkeypatch):
    # Zero the retry backoff: the tests below assert *how many* attempts
    # happen, never how long they wait, and the real (0.5s, 1.0s) delays
    # would otherwise add ~6s of pure sleeping to the suite.
    monkeypatch.setattr(off_client, "_RETRY_BACKOFF_SECONDS", (0, 0))
    off_client._CACHE.clear()
    yield
    off_client._CACHE.clear()


def _http_status_error(status_code: int) -> httpx.HTTPStatusError:
    request = httpx.Request("GET", "https://example.invalid")
    response = httpx.Response(status_code, request=request)
    return httpx.HTTPStatusError("boom", request=request, response=response)


def _stub_request(monkeypatch, side_effect):
    """Replaces the single-attempt helper (not _fetch_off itself) so the retry
    loop in _fetch_off is exercised for real. Returns a call counter."""
    calls = {"n": 0}

    async def _stub(barcode: str) -> dict:
        calls["n"] += 1
        return side_effect(calls["n"])

    monkeypatch.setattr(off_client, "_request_off", _stub)
    return calls


def test_cache_hit_returns_stored_result():
    off_client._cache_set("111", {"name": "Test"})
    assert off_client._cache_get("111") == (True, {"name": "Test"})


def test_expired_entry_is_a_miss_and_is_dropped():
    off_client._CACHE["111"] = (0.0, {"name": "Test"})  # already expired
    assert off_client._cache_get("111") == (False, None)
    assert "111" not in off_client._CACHE


def test_not_found_results_are_cached_too():
    off_client._cache_set("222", None)
    assert off_client._CACHE["222"][1] is None


def test_evict_caps_the_cache(monkeypatch):
    import time

    for i in range(off_client._MAX_ENTRIES + 5):
        off_client._CACHE[str(i)] = (time.monotonic() + 1000, {"i": i})
    off_client._evict()
    assert len(off_client._CACHE) <= off_client._MAX_ENTRIES


def test_uninitialized_client_is_an_error_not_an_attribute_error():
    """If init_client() never ran (or close_client() already did),
    _request_off must raise an httpx.HTTPError so _fetch_off's retry/error
    handling still applies and lookup_off's OffLookupError contract holds."""
    assert off_client._client is None
    assert asyncio.run(off_client._fetch_off("777")) is _ERROR


def test_init_and_close_manage_the_shared_client():
    off_client.init_client()
    assert off_client._client is not None
    asyncio.run(off_client.close_client())
    assert off_client._client is None


def test_retries_a_transient_failure_then_succeeds(monkeypatch):
    def _flaky(n):
        if n < _MAX_ATTEMPTS:
            raise httpx.ConnectError("simulated network failure")
        return {"status": 1, "product": {"product_name": "Retried Product"}}

    calls = _stub_request(monkeypatch, _flaky)
    result = asyncio.run(off_client._fetch_off("444"))
    assert calls["n"] == _MAX_ATTEMPTS
    assert result["name"] == "Retried Product"


def test_gives_up_as_error_once_every_attempt_fails(monkeypatch):
    def _always_500(_n):
        raise _http_status_error(500)

    calls = _stub_request(monkeypatch, _always_500)
    assert asyncio.run(off_client._fetch_off("555")) is _ERROR
    assert calls["n"] == _MAX_ATTEMPTS


def test_clean_404_is_a_miss_and_is_not_retried(monkeypatch):
    """A 404 is a real answer, not a glitch -- so it must be cacheable (None),
    never the never-cached _ERROR sentinel."""

    def _clean_404(_n):
        raise _http_status_error(404)

    calls = _stub_request(monkeypatch, _clean_404)
    assert asyncio.run(off_client._fetch_off("666")) is None
    assert calls["n"] == 1


def test_malformed_response_is_a_miss_not_an_outage(monkeypatch):
    """An HTML rate-limit page instead of JSON is a response we did get, just
    not a usable one -- answered as "not found", never escalated."""

    def _always_malformed(_n):
        raise ValueError("simulated JSON decode failure")

    calls = _stub_request(monkeypatch, _always_malformed)
    assert asyncio.run(off_client._fetch_off("888")) is None
    assert calls["n"] == _MAX_ATTEMPTS


def test_lookup_raises_on_error_and_never_caches_it(monkeypatch):
    monkeypatch.setattr(
        off_client, "_fetch_off", lambda barcode: asyncio.sleep(0, result=_ERROR)
    )
    with pytest.raises(OffLookupError):
        asyncio.run(off_client.lookup_off("333"))
    assert "333" not in off_client._CACHE

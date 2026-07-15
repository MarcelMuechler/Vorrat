import asyncio
import time
from urllib.parse import quote

import httpx

from app.config import settings

# In-memory lookup cache, keyed by barcode -> (expiry_monotonic, result).
# Deliberately per-process and unbounded-by-persistence: it resets on
# restart, which is fine for a cache of network lookups on a single-process
# app. lookup_off is a plain `async def` awaited on the FastAPI event loop
# (not dispatched to the threadpool, which is only for sync endpoints), so
# there's no real concurrent mutation of _CACHE across OS threads and no
# lock is needed here.
_CACHE: dict[str, tuple[float, dict | None]] = {}
_TTL_FOUND_SECONDS = 24 * 60 * 60
_TTL_NOT_FOUND_SECONDS = 60 * 60
_MAX_ENTRIES = 1000

# Sentinel distinguishing "the request itself failed" (network error, timeout,
# malformed response) from a genuine OFF "product not found" (None). Errors
# must never be cached: a transient outage would otherwise poison the barcode
# as not-found for an hour, when a retry a second later might succeed.
_ERROR = object()

# Retry policy for transient failures (network errors, timeouts, 429, 5xx).
# 3 attempts total, short exponential backoff between them. A per-request
# timeout of 3s (rather than the previous 5s) keeps the worst case (every
# attempt genuinely times out) close to the old single-shot latency instead
# of tripling it — a barcode scan shouldn't be left hanging for ~15s.
_MAX_ATTEMPTS = 3
_RETRY_BACKOFF_SECONDS = (0.5, 1.0)
_REQUEST_TIMEOUT_SECONDS = 3.0


def _cache_get(barcode: str) -> tuple[bool, dict | None]:
    """Returns (hit, result). A stale entry counts as a miss and is dropped."""
    entry = _CACHE.get(barcode)
    if entry is None:
        return False, None
    expiry, result = entry
    if time.monotonic() >= expiry:
        del _CACHE[barcode]
        return False, None
    return True, result


def _cache_set(barcode: str, result: dict | None) -> None:
    ttl = _TTL_FOUND_SECONDS if result is not None else _TTL_NOT_FOUND_SECONDS
    _CACHE[barcode] = (time.monotonic() + ttl, result)
    if len(_CACHE) > _MAX_ENTRIES:
        _evict()


def _evict() -> None:
    """Drop expired entries first, then the oldest-expiring ones until back at the cap."""
    now = time.monotonic()
    for key in [k for k, (expiry, _) in _CACHE.items() if expiry <= now]:
        del _CACHE[key]
    overflow = len(_CACHE) - _MAX_ENTRIES
    if overflow > 0:
        oldest = sorted(_CACHE.items(), key=lambda kv: kv[1][0])[:overflow]
        for key, _ in oldest:
            del _CACHE[key]


async def lookup_off(barcode: str) -> dict | None:
    """Look up a barcode on Open Food Facts. Returns a Product-shaped dict or None.

    Never raises: any network error, timeout, or "not found" response from OFF
    is treated the same way as a genuine miss. Results are cached in-process
    for a while (see _TTL_*_SECONDS) so repeated scans of the same barcode
    don't hit the network every time.
    """
    hit, cached = _cache_get(barcode)
    if hit:
        return cached

    result = await _fetch_off(barcode)
    if result is _ERROR:
        # Transient failure: don't cache, so the next scan retries immediately.
        return None
    _cache_set(barcode, result)
    return result


async def _request_off(barcode: str) -> dict:
    """A single OFF request attempt. Raises httpx.HTTPError/ValueError on failure."""
    url = f"{settings.off_base_url}/api/v2/product/{quote(barcode, safe='')}.json"
    headers = {"User-Agent": settings.off_user_agent}
    async with httpx.AsyncClient(timeout=_REQUEST_TIMEOUT_SECONDS) as client:
        response = await client.get(url, headers=headers)
        response.raise_for_status()
        return response.json()


async def _fetch_off(barcode: str) -> dict | None | object:
    data = None
    for attempt in range(_MAX_ATTEMPTS):
        try:
            data = await _request_off(barcode)
            break
        except httpx.HTTPStatusError as exc:
            # A genuine 4xx like 404 "not found" is a clean answer, not a
            # transient failure — retrying it would just waste time, and
            # unlike a real error it's safe (and desirable) to cache as a miss.
            status = exc.response.status_code
            retryable = status == 429 or status >= 500
            if not retryable:
                return None
            if attempt == _MAX_ATTEMPTS - 1:
                return _ERROR
        except (httpx.HTTPError, ValueError):
            # ValueError covers response.json() raising JSONDecodeError, e.g. OFF
            # returning a 200 with an HTML rate-limit/maintenance page instead of
            # JSON — treated as transient and retried like a network error. But
            # unlike a genuine "not found", a failed request must not be cached.
            if attempt == _MAX_ATTEMPTS - 1:
                return _ERROR
        await asyncio.sleep(_RETRY_BACKOFF_SECONDS[attempt])

    if data.get("status") != 1:
        return None

    off_product = data.get("product", {})
    name = off_product.get("product_name") or off_product.get("product_name_en")
    if not name:
        return None

    category = (off_product.get("categories") or "").split(",")[0].strip() or None
    image_url = off_product.get("image_front_small_url") or off_product.get("image_url")

    # OFF already normalizes the free-text "quantity" field (e.g. "33 cl")
    # into a numeric product_quantity + unit when its data is populated --
    # no need to parse the free-text version ourselves. Both are frequently
    # missing/empty for a given product, hence the permissive fallback to
    # omitting them entirely rather than guessing.
    amount = off_product.get("product_quantity")
    quantity_unit = off_product.get("product_quantity_unit") or None

    return {
        "barcode": barcode,
        "name": name,
        "category": category,
        "image_url": image_url,
        "amount": float(amount) if amount else None,
        "quantity_unit": quantity_unit,
    }


if __name__ == "__main__":
    # Offline self-check of the cache logic (no network involved).
    _cache_set("111", {"name": "Test"})
    assert _cache_get("111") == (True, {"name": "Test"})

    _CACHE["111"] = (time.monotonic() - 1, {"name": "Test"})  # force expiry
    assert _cache_get("111") == (False, None)
    assert "111" not in _CACHE

    _cache_set("222", None)  # not-found results are cached too, shorter TTL
    assert _CACHE["222"][1] is None

    _CACHE.clear()
    for i in range(_MAX_ENTRIES + 5):
        _CACHE[str(i)] = (time.monotonic() + 1000, {"i": i})
    _evict()
    assert len(_CACHE) <= _MAX_ENTRIES

    def _http_status_error(status_code: int) -> httpx.HTTPStatusError:
        request = httpx.Request("GET", "https://example.invalid")
        response = httpx.Response(status_code, request=request)
        return httpx.HTTPStatusError("boom", request=request, response=response)

    # Retries a transient failure and succeeds once the network recovers.
    # These stub out _request_off (the single-attempt helper) rather than
    # _fetch_off itself, so the retry loop in _fetch_off is exercised for real.
    _calls = {"n": 0}

    async def _flaky_then_ok(barcode: str) -> dict:
        _calls["n"] += 1
        if _calls["n"] < _MAX_ATTEMPTS:
            raise httpx.ConnectError("simulated network failure")
        return {"status": 1, "product": {"product_name": "Retried Product"}}

    _request_off = _flaky_then_ok
    result = asyncio.run(_fetch_off("444"))
    assert _calls["n"] == _MAX_ATTEMPTS  # failed twice, succeeded on the last attempt
    assert result["name"] == "Retried Product"

    # Gives up (as _ERROR) once every attempt fails, without exceeding the budget.
    _calls = {"n": 0}

    async def _always_500(barcode: str) -> dict:
        _calls["n"] += 1
        raise _http_status_error(500)

    _request_off = _always_500
    assert asyncio.run(_fetch_off("555")) is _ERROR
    assert _calls["n"] == _MAX_ATTEMPTS

    # A clean 404 "not found" is not retried — it's a real answer, not a glitch —
    # and it must be cacheable (None), not the never-cached _ERROR sentinel.
    _calls = {"n": 0}

    async def _clean_404(barcode: str) -> dict:
        _calls["n"] += 1
        raise _http_status_error(404)

    _request_off = _clean_404
    assert asyncio.run(_fetch_off("666")) is None
    assert _calls["n"] == 1  # no retry attempted

    _CACHE.clear()
    _fetch_off = lambda barcode: asyncio.sleep(0, result=_ERROR)  # noqa: E731 — simulate a network failure
    assert asyncio.run(lookup_off("333")) is None  # never-raises contract holds
    assert "333" not in _CACHE  # but the error is NOT cached

    print("off_client self-check OK")

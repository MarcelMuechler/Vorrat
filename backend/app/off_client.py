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


class OffLookupError(Exception):
    """Raised when Open Food Facts couldn't be reached or answered at all --
    a timeout, connection failure, or repeated 5xx/429 after retries are
    exhausted. Distinct from a genuine "not found" (returned as None): a
    caller must not treat this the same as a real miss, since the product
    may well exist and the user shouldn't be told to enter it manually just
    because of a transient network problem.
    """


# Lifecycle-managed HTTP client, reused across all OFF requests (and retries)
# for connection pooling / TCP+TLS reuse. Set by init_client() during FastAPI
# lifespan startup and torn down by close_client() on shutdown. A plain
# module-level holder rather than an abstraction layer -- also lets a test
# swap in a stub/mock client directly.
_client: httpx.AsyncClient | None = None


def init_client() -> None:
    """Create the shared OFF HTTP client. Call once during app startup."""
    global _client
    _client = httpx.AsyncClient(timeout=_REQUEST_TIMEOUT_SECONDS)


async def close_client() -> None:
    """Close the shared OFF HTTP client. Call once during app shutdown."""
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


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
    """Look up a barcode on Open Food Facts. Returns a Product-shaped dict, or
    None for a genuine "not found" -- a clean 404, a well-formed response with
    no matching product, or a malformed/unexpected-but-received response
    (those are treated as answers, not failures).

    Raises OffLookupError if OFF couldn't be reached or answered at all
    (timeout, connection failure, repeated 5xx/429) after retries are
    exhausted -- a real failure, distinct from a genuine miss, that callers
    must not silently swallow. Results are cached in-process for a while (see
    _TTL_*_SECONDS) so repeated scans of the same barcode don't hit the
    network every time; errors are never cached (see _ERROR).
    """
    hit, cached = _cache_get(barcode)
    if hit:
        return cached

    result = await _fetch_off(barcode)
    if result is _ERROR:
        # Transient failure: don't cache, so the next scan retries immediately.
        raise OffLookupError(f"Open Food Facts lookup failed for barcode {barcode!r}")
    _cache_set(barcode, result)
    return result


async def _request_off(barcode: str) -> dict:
    """A single OFF request attempt. Raises httpx.HTTPError/ValueError on failure."""
    if _client is None:
        # Not initialized (init_client() wasn't called, e.g. lifespan didn't
        # run) or already closed. Raise an httpx.HTTPError subclass rather
        # than letting an AttributeError through, so _fetch_off's retry/error
        # handling (and lookup_off's OffLookupError contract for genuine
        # connectivity failures) still applies.
        raise httpx.ConnectError("OFF HTTP client not initialized")
    url = f"{settings.off_base_url}/api/v2/product/{quote(barcode, safe='')}.json"
    headers = {"User-Agent": settings.off_user_agent}
    response = await _client.get(url, headers=headers)
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
        except ValueError:
            # response.json() raised (e.g. JSONDecodeError) -- OFF responded, just
            # not with parseable JSON (an HTML rate-limit/maintenance page is the
            # common case). We did get *a* response, so this is answered like a
            # genuine miss (None), not a transport failure -- still retried first
            # in case it's a one-off blip, but never escalated to OffLookupError.
            if attempt == _MAX_ATTEMPTS - 1:
                return None
        except httpx.HTTPError:
            # No response at all: timeout, connection refused, DNS failure, etc.
            # Retried like the above, but unlike a malformed response this is a
            # genuine failure to reach OFF -- if every attempt fails, it must
            # propagate as OffLookupError, not be cached as a false "not found".
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

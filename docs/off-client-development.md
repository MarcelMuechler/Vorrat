# Open Food Facts (OFF) Development

Vorrat's barcode lookup feature integrates with the Open Food Facts API. This document covers development and testing workflows to avoid hitting the real API during development.

## Architecture

The `backend/app/off_client.py` module handles all Open Food Facts API interactions with built-in caching:

- **In-memory cache**: Lookup results are cached per process with configurable TTLs:
  - Found products: cached for 24 hours
  - Not-found results: cached for 1 hour
  - Network errors are **never cached** — transient failures allow immediate retries
- **Cache eviction**: When the cache exceeds 1000 entries, oldest entries are evicted
- **Never raises**: Network errors, timeouts, and malformed responses are treated the same as a genuine "not found" — the API always returns either a product dict or `None`

## Configuration

The OFF client is configured via environment variables in `backend/app/config.py`:

| Variable | Default | Description |
|----------|---------|-------------|
| `OFF_BASE_URL` | `https://world.openfoodfacts.org` | Base URL for the OFF API. Override this to point at a test double, a regional OFF instance, or a self-hosted mirror. |
| `OFF_USER_AGENT` | `Vorrat/0.1 (+https://github.com/MarcelMuechler/vorrat)` | User-Agent header sent to OFF. Customize only if requested by the OFF maintainers. |

## Offline Development

### Option 1: Use the Self-Check (No Network)

The `off_client` module includes a self-check that tests the cache logic without any network calls:

```sh
cd backend
python -m app.off_client
```

Output on success:
```
off_client self-check OK
```

This validates:
- Cache hit/miss behavior
- TTL expiration
- Not-found caching (with shorter TTL)
- Cache eviction when capacity is exceeded
- Error handling (transient failures are not cached)

Run this to verify cache behavior before committing changes to `off_client.py`.

### Option 2: Mock the OFF API Endpoint

Point the barcode lookup at a local mock server instead of the real API:

```sh
# Start your backend dev server
cd backend
export OFF_BASE_URL=http://localhost:9000
uv run uvicorn app.main:app --reload
```

Then in another terminal, start a simple mock server:

```sh
python3 -m http.server 9000 --directory ./mocks
```

Create a `backend/mocks/api/v2/product/` directory structure and add mock responses as JSON files named after barcodes:

```
backend/mocks/
└── api/
    └── v2/
        └── product/
            ├── 5010477007856.json    # Cheese
            ├── 3017620425035.json    # Milk
            └── 0000000000001.json    # Not found (return {"status": 0})
```

Example mock response (`5010477007856.json`):
```json
{
  "status": 1,
  "product": {
    "product_name": "Cheddar Cheese",
    "categories": "Cheese, Dairy Products",
    "image_url": "https://example.com/image.jpg",
    "product_quantity": 200,
    "product_quantity_unit": "g"
  }
}
```

Example "not found" response:
```json
{
  "status": 0
}
```

With this setup, barcode scans use your local mock responses and the real API is never contacted.

### Option 3: Use a Regional OFF Mirror

The Open Food Facts project provides regional instances (e.g., `https://de.openfoodfacts.org` for Germany). Point your dev instance at one:

```sh
export OFF_BASE_URL=https://de.openfoodfacts.org
cd backend
uv run uvicorn app.main:app --reload
```

This hits a real API but avoids the main global instance. Useful for testing region-specific product data or reducing load on the primary server during heavy development.

### Option 4: Offline Mode (No Barcode Lookups)

To completely disable barcode lookups (and prevent any OFF API calls), you can mock the `lookup_off` function by wrapping it in your test. See the self-check in `off_client.py` (lines 142–144) for an example of how the module tests offline behavior.

## Caching Behavior

The cache is **in-process only** — it resets when the backend restarts. This is intentional:

- **Development**: Cache persists across requests within a single server run, speeding up repeated scans of the same barcode
- **Deployment**: Each restart gets a clean cache, preventing stale data from persisting indefinitely
- **No disk**: No persistent cache file is created — the cache is purely in-memory

To test cache behavior during development:

1. Scan a barcode (e.g., "5010477007856")
2. Scan it again — the cached result is returned instantly
3. Restart `uvicorn` — the cache is cleared
4. Scan again — the API is hit (or your mock is called)

## Integration Testing

For integration tests or CI workflows that need to run without the real OFF API:

1. **Offline self-check**: Run `python -m app.off_client` to verify cache logic
2. **Mock server**: Start a local mock server (as described in Option 2) and point tests at it via `OFF_BASE_URL`
3. **Fixture setup**: In a test suite, set `OFF_BASE_URL` to a test double before running integration tests

## Error Handling

The OFF client never raises exceptions — all failures return `None`:

- Network timeouts (5-second limit per request)
- HTTP errors (4xx, 5xx)
- Malformed JSON responses
- OFF returning a valid response with `"status": 0` (product not found)

All of these cases are treated identically: `lookup_off()` returns `None`, and the barcode scan proceeds without product details. The frontend shows "Unknown product" and lets the user enter details manually.

**Important**: Network errors are never cached. If the OFF API is temporarily unavailable, the next scan of the same barcode will attempt the lookup again (no silent failures due to poisoned cache).

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Vorrat is a self-hosted household stock/inventory manager (a Grocy alternative): stock overview
with best-before-date tracking, barcode scanning, and Open Food Facts lookup for unknown
products. It's deployable as a Home Assistant add-on or standalone via Docker. There is
deliberately no authentication (v1) — it's built to run only on a trusted home network or
behind HA Ingress.

## Layout

- `backend/` — FastAPI + SQLAlchemy + Alembic + SQLite REST API
- `frontend/` — Flutter app (Android, iOS, Web)
- `vorrat/` — Home Assistant add-on packaging (`config.yaml`, `Dockerfile`, `rootfs`)
- `docs/` — architecture notes

## Commands

Backend (from `backend/`):
```sh
uv run uvicorn app.main:app --reload      # dev server, http://localhost:8000
alembic upgrade head                       # apply migrations (needed before first run)
alembic revision --autogenerate -m "..."   # new migration after a models.py change
uv run pytest                              # isolated unit tests (backend/tests/, in-memory SQLite via TestClient)
BASE=http://localhost:8000 ./scripts/smoke_test.sh   # curl-based end-to-end regression check
```
Two complementary layers of backend testing: `pytest` (`backend/tests/`) runs fast, isolated
unit tests against FastAPI's `TestClient` and an in-memory SQLite db (see `tests/conftest.py`'s
`client` fixture) — no live server needed, extend this in place for new router/db-logic
coverage. `scripts/smoke_test.sh` stays as the live end-to-end regression check, run against a
real `uvicorn` instance — extend it in place too for checks that specifically need a live
server (e.g. exercising the actual HTTP stack/CORS/static file serving), rather than starting a
third parallel test framework.

Frontend (from `frontend/`):
```sh
flutter analyze     # lint
flutter test        # the one widget test (app boots to the Stock tab)
flutter build web && python3 -m http.server 8090 -d build/web   # serve a web build locally
```
When running the Flutter dev server standalone against a local backend, point Settings →
Server URL at `http://localhost:8000` — the dev server and `uvicorn` are on different origins,
so the same-origin-relative API calls used in the HA/Docker deployment don't apply.

Docker (from repo root):
```sh
docker build -f vorrat/Dockerfile -t vorrat .
docker run -d -p 8099:8099 -v vorrat-data:/data vorrat
```

## Architecture

**Single deployable, two build stages.** `vorrat/Dockerfile` builds the Flutter web app in one
stage (`flutter build web --base-href=/__INGRESS_BASE__/`) and copies the output into
`backend/app/static/`; the FastAPI app in `backend/app/main.py` serves both the REST API and
that static SPA from one process on port 8099. Plain local backend dev (no `app/static/`) just
runs API-only — `main.py` checks `STATIC_DIR.exists()` before mounting the SPA routes.

**HA Ingress base-href rewrite.** Home Assistant serves the add-on under a dynamic per-session
path prefix and sets `X-Ingress-Path` on proxied requests. The Flutter build bakes in the
literal marker `<base href="/__INGRESS_BASE__/">` (a deliberate, stable token — not Flutter's
default `"/"`, so the replace isn't pattern-matching Flutter's default output, which could
change across SDK versions); `main.py`'s `/` route swaps that marker for the actual ingress
path on each request. `ApiClient._uri()` in `frontend/lib/api/client.dart` mirrors this: API
paths are written base-relative (no leading slash) so they resolve against `<base href>`
correctly in every mode (standalone, ingress, native apps with an explicit server URL).

**Two-repo release process.** Home Assistant's add-on store does not track this repo — the
custom repository actually registered in HA is a separate thin wrapper,
[`vorrat-hassio-addon`](https://github.com/MarcelMuechler/vorrat-hassio-addon), whose
Dockerfile clones this repo at a pinned git tag (`ARG VORRAT_REF`) at build time. Bumping a
version here (backend/pyproject.toml, frontend/pubspec.yaml, vorrat/config.yaml) does nothing
in HA until that tag is cut and the wrapper repo's `VORRAT_REF` + `config.yaml` version are
bumped to match — see the "Releasing" section in `README.md` for the exact steps. `VORRAT_REF`
must be a tag, never a floating branch: Docker caches the wrapper's `RUN git clone` layer by
its literal command text, so a branch ref cache-hits forever and silently keeps serving
whatever was cloned on the very first build.

**Data model** (`backend/app/models.py`): `Location` → `Product` (optional default location) →
`StockEntry` (amount + optional best-before/purchased dates). SQLite foreign keys are off by
default and are explicitly turned on per-connection in `db.py` (otherwise deleting a `Product`
would silently orphan its `StockEntry` rows instead of raising). `stock.py`'s `list_stock`
computes an `ok` / `expiring_soon` / `expired` status from `best_before_date` vs.
`settings.expiring_soon_days`, and uses `contains_eager`/`joinedload` to avoid N+1 queries when
listing.

**Barcode lookup** (`routers/barcode.py`): checks the local `Product` table first; on a miss,
falls back to Open Food Facts (`off_client.lookup_off`). A malformed/non-JSON response is still
treated as a genuine "not found" (`None`), but a real connectivity failure (timeout, connection
error, repeated 5xx/429 after retries) raises `OffLookupError`, which the router turns into an
HTTP 503 rather than a 404 — the OFF outage case must stay distinguishable from a genuine miss.

**Search.** Product/stock name search uses `ilike` with `escape_like()` (`utils.py`) so literal
`%`/`_`/`\` in a user's search term aren't treated as SQL LIKE wildcards.

**Frontend state.** `provider`-based: `SettingsProvider` (server URL, persisted via
`shared_preferences`) and `StockProvider` (stock list + filter state) are wired up in
`main.dart`'s `MultiProvider`. `ApiClient` throws `ApiException` on any non-2xx response — don't
let new client methods swallow failures silently.

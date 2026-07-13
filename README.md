# Vorrat

Self-hosted household stock/inventory management — a Grocy alternative.

## Features

- Stock overview with best-before-date tracking
- Barcode scanning (Android, iOS, Web)
- Open Food Facts lookup for unknown products
- Deployable as a Home Assistant app, or standalone via Docker

## Layout

- `backend/` — FastAPI + SQLAlchemy + Alembic + SQLite REST API
- `frontend/` — Flutter app (Android, iOS, Web)
- `vorrat/` — Home Assistant app packaging (config, Dockerfile)
- `docs/` — architecture notes

## Development

```sh
# backend
cd backend && uv run uvicorn app.main:app --reload

# frontend (point Settings → Server URL at http://localhost:8000 once running,
# since the Flutter dev server and uvicorn are on different origins)
cd frontend && flutter build web && python3 -m http.server 8090 -d build/web
```

## Installing on Home Assistant

In Home Assistant, go to Settings → Add-ons → Add-on Store → ⋮ → Repositories, and add
[`vorrat-hassio-addon`](https://github.com/MarcelMuechler/vorrat-hassio-addon) — a thin
wrapper repo that clones this repo's tagged releases at build time (see "Releasing" below
for why it's separate). Install "Vorrat" from the store, start it, and open it from the
sidebar. See [`vorrat/DOCS.md`](vorrat/DOCS.md) for mobile app setup.

## Commit message convention

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
`<type>: <description>`, e.g. `fix: reject non-positive amounts in consume_stock` or
`feat: add partial stock consumption to the overview screen`. This repo's history already
follows this — see `git log` — so it's a matter of keeping it up, not a new habit.

The type determines the version bump, via [release-please](https://github.com/googleapis/release-please) (`.github/workflows/release-please.yml`):

- `fix:` → patch
- `feat:` → minor
- A `!` after the type (e.g. `feat!:`) or a `BREAKING CHANGE:` footer → major
- `chore:`, `docs:`, `refactor:`, etc. → no bump, unless they carry a `BREAKING CHANGE:` footer

## Releasing

release-please watches `main` and keeps a standing "Release PR" up to date, bumping
`backend/pyproject.toml`, `frontend/pubspec.yaml`, `vorrat/config.yaml`, and `CHANGELOG.md`
to whatever version the commits since the last release call for (see "Commit message
convention" above). Nothing is tagged or released until you merge that PR — review it like
any other PR, then merge:

1. Merge the open "chore(main): release X.Y.Z" PR. This tags `vX.Y.Z` and cuts a GitHub
   Release.
2. The same workflow run then automatically syncs
   [`vorrat-hassio-addon`](https://github.com/MarcelMuechler/vorrat-hassio-addon) — bumping
   `vorrat/config.yaml`'s `version` and `vorrat/Dockerfile`'s `ARG VORRAT_REF` to the new tag
   and pushing — since the Home Assistant add-on store only rechecks *that* repo's
   `config.yaml` for a new `version` string; it never looks at this repo directly, and never
   re-runs a Docker build on its own.
   - Requires a `HASSIO_ADDON_PAT` repository secret (a PAT with write access to
     `vorrat-hassio-addon`) — the default `GITHUB_TOKEN` can't push to a different repo.
     Without it, this step fails loudly rather than silently skipping.
   - `VORRAT_REF` must point at a tag, never `main` — Docker caches the `RUN git clone`
     layer by its literal command text, so a floating branch ref cache-hits forever and
     rebuilds silently keep serving whatever was cloned on the very first build.
3. In Home Assistant: Settings → Add-ons → Add-on Store → ⋮ → **Check for updates** (a
   plain reinstall/rebuild does *not* refresh the store's cached repo metadata), then
   update the Vorrat add-on. This last step is still manual — it happens on the HA instance,
   outside GitHub's reach.

## Running standalone via Docker

```sh
docker build -f vorrat/Dockerfile -t vorrat .
docker run -d -p 8099:8099 -v vorrat-data:/data vorrat
```

No authentication in v1 — intended for a trusted home network / Home Assistant Ingress.

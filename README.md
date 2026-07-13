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

The type determines the version bump once #21 automates this (until then, it's still the
mental model behind the manual bump in "Releasing" below):

- `fix:` → patch
- `feat:` → minor
- A `!` after the type (e.g. `feat!:`) or a `BREAKING CHANGE:` footer → major
- `chore:`, `docs:`, `refactor:`, etc. → no bump, unless they carry a `BREAKING CHANGE:` footer

## Releasing

The Home Assistant add-on store only rechecks a repository's `config.yaml` for a new
`version` string — it never looks at this repo directly, and it never re-runs a Docker
build on its own. Cutting a release means touching both repos:

1. In this repo, bump the version to the same value in all three places and push to `main`:
   - `backend/pyproject.toml` (`version`)
   - `frontend/pubspec.yaml` (`version`)
   - `vorrat/config.yaml` (`version`)
2. Tag the release and push the tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. In [`vorrat-hassio-addon`](https://github.com/MarcelMuechler/vorrat-hassio-addon), bump
   `vorrat/config.yaml`'s `version` to match, and bump the `ARG VORRAT_REF` default in
   `vorrat/Dockerfile` to the new tag. Commit and push.
   - `VORRAT_REF` must point at a tag, never `main` — Docker caches the `RUN git clone`
     layer by its literal command text, so a floating branch ref cache-hits forever and
     rebuilds silently keep serving whatever was cloned on the very first build.
4. In Home Assistant: Settings → Add-ons → Add-on Store → ⋮ → **Check for updates** (a
   plain reinstall/rebuild does *not* refresh the store's cached repo metadata), then
   update the Vorrat add-on.

## Running standalone via Docker

```sh
docker build -f vorrat/Dockerfile -t vorrat .
docker run -d -p 8099:8099 -v vorrat-data:/data vorrat
```

No authentication in v1 — intended for a trusted home network / Home Assistant Ingress.

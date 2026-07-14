from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles

from app import __version__
from app.routers import (
    barcode,
    categories,
    consumption_log,
    locations,
    products,
    settings,
    stats,
    stock,
)

app = FastAPI(title="Vorrat", version=__version__)
print(f"Vorrat backend v{__version__} starting", flush=True)

# ponytail: allow_origins=["*"] is fine here, v1 has no auth and this only
# ever runs on a trusted home network / behind HA Ingress.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(locations.router)
app.include_router(categories.router)
app.include_router(products.router)
app.include_router(stock.router)
app.include_router(barcode.router)
app.include_router(settings.router)
app.include_router(consumption_log.router)
app.include_router(stats.router)


@app.get("/api/health")
def health():
    return {"status": "ok", "version": __version__}


# The Flutter web build only exists once the Docker image copies it in (see
# vorrat/Dockerfile) — plain local backend dev runs API-only.
STATIC_DIR = Path(__file__).parent / "static"

if STATIC_DIR.exists():

    # vorrat/Dockerfile builds with `flutter build web
    # --base-href=/__INGRESS_BASE__/` — a stable, deliberate marker instead of
    # Flutter's default "/", so this replace targets an exact token we chose
    # rather than pattern-matching Flutter's default rendered output (which
    # could change quote style/whitespace/default across SDK versions).
    _BASE_HREF_MARKER = '<base href="/__INGRESS_BASE__/">'

    @app.get("/", include_in_schema=False)
    def index(request: Request):
        # HA Ingress serves this app under a dynamic per-session path prefix
        # and sets X-Ingress-Path on proxied requests. The app keeps Flutter's
        # default hash-based routing, so this rewrite on the initial document
        # load is the only place ingress-awareness is needed.
        ingress_path = request.headers.get("X-Ingress-Path", "")
        html = (STATIC_DIR / "index.html").read_text()
        html = html.replace(_BASE_HREF_MARKER, f'<base href="{ingress_path}/">')
        return HTMLResponse(html)

    app.mount("/", StaticFiles(directory=STATIC_DIR), name="static")

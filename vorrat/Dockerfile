# Supervisor no longer auto-injects BUILD_FROM (since 2026.04.0), so it needs
# an explicit default here. Declared before any FROM so it's in scope for
# both build stages below.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.23

# Pinned to a specific, tested Flutter release (tag + content digest) instead
# of the mutable `:stable` tag, which can point to a different SDK version on
# different days and silently change what gets built.
FROM ghcr.io/cirruslabs/flutter:3.44.0@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS webbuilder
COPY frontend/ /src
# A stable, greppable marker instead of the default "/" — main.py replaces
# this exact token for HA Ingress instead of pattern-matching Flutter's
# default rendered <base href> output, which could change across SDK versions.
RUN cd /src && flutter build web --base-href=/__INGRESS_BASE__/

# uv's official distroless image ships a statically-linked (musl-compatible)
# binary — copying just the executable out of it is the documented way to
# add uv to another base image.
FROM ghcr.io/astral-sh/uv:0.11.28@sha256:0f36cb9361a3346885ca3677e3767016687b5a170c1a6b88465ec14aefec90aa AS uv

# Resolve the locked backend dependency set into a venv. This stage is based
# on the *same* Alpine image as the runtime stage below so the venv's
# compiled extensions (pydantic-core, uvloop, ...) are ABI-compatible when
# copied across.
FROM ${BUILD_FROM} AS backend-builder
RUN apk add --no-cache python3
COPY --from=uv /uv /usr/local/bin/uv
WORKDIR /app
COPY backend/pyproject.toml backend/uv.lock /app/
# --frozen installs exactly what's pinned in uv.lock and fails instead of
# silently re-resolving if pyproject.toml and uv.lock have drifted apart.
# --no-install-project skips installing vorrat-backend itself: the runtime
# stage below runs straight from the copied source tree, not an installed
# package.
RUN uv sync --frozen --no-install-project --no-dev

FROM ${BUILD_FROM} AS runtime

RUN apk add --no-cache python3

# Run straight from the source tree (no package install step) so that
# copying the Flutter web build into app/static below lands where main.py
# actually looks for it at runtime.
WORKDIR /app
COPY backend/ /app
COPY --from=backend-builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:${PATH}"
COPY --from=webbuilder /src/build/web /app/app/static
COPY vorrat/rootfs /

LABEL \
    org.opencontainers.image.title="Vorrat" \
    org.opencontainers.image.description="Self-hosted grocery & stock management" \
    org.opencontainers.image.source="https://github.com/MarcelMuechler/vorrat" \
    org.opencontainers.image.licenses="MIT"

# Supervisor no longer auto-injects BUILD_FROM (since 2026.04.0), so it needs
# an explicit default here. Declared before any FROM so it's in scope for
# both build stages below.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.23

FROM ghcr.io/cirruslabs/flutter:stable AS webbuilder
COPY frontend/ /src
# A stable, greppable marker instead of the default "/" — main.py replaces
# this exact token for HA Ingress instead of pattern-matching Flutter's
# default rendered <base href> output, which could change across SDK versions.
RUN cd /src && flutter build web --base-href=/__INGRESS_BASE__/

FROM ${BUILD_FROM} AS runtime

RUN apk add --no-cache python3 py3-pip \
    && pip install --break-system-packages --no-cache-dir \
        fastapi "uvicorn[standard]" sqlalchemy alembic httpx pydantic-settings

# Run straight from the source tree (no package install step) so that
# copying the Flutter web build into app/static below lands where main.py
# actually looks for it at runtime.
WORKDIR /app
COPY backend/ /app
COPY --from=webbuilder /src/build/web /app/app/static
COPY vorrat/rootfs /

LABEL \
    org.opencontainers.image.title="Vorrat" \
    org.opencontainers.image.description="Self-hosted grocery & stock management" \
    org.opencontainers.image.source="https://github.com/MarcelMuechler/vorrat" \
    org.opencontainers.image.licenses="MIT"

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./vorrat.db"
    off_user_agent: str = "Vorrat/0.1 (+https://github.com/MarcelMuechler/vorrat)"
    off_base_url: str = "https://world.openfoodfacts.org"
    expiring_soon_days: int = 3
    # Mirrors database_url's pattern: a relative path for local dev, pointed
    # at the persisted /data volume by an env var in the HA/Docker image (see
    # vorrat/rootfs/etc/services.d/vorrat/run) so uploaded product photos
    # survive container recreation the same way the sqlite db does -- unlike
    # everything else under backend/app/, which is baked into the image and
    # wiped on every rebuild.
    uploads_dir: str = "uploads"


settings = Settings()

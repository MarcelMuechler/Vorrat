from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./vorrat.db"
    off_user_agent: str = "Vorrat/0.1 (+https://github.com/MarcelMuechler/vorrat)"
    off_base_url: str = "https://world.openfoodfacts.org"
    expiring_soon_days: int = 3


settings = Settings()

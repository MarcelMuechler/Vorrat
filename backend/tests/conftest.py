import os
import tempfile
from collections.abc import Iterator

# main.py and products.py each eagerly create settings.uploads_dir (default
# "uploads", relative to cwd) at import time, as soon as `from app.main
# import app` below runs -- before any per-test fixture gets a chance to
# monkeypatch anything. Redirecting it to a throwaway directory here, before
# that first import happens, keeps the whole test run from ever creating the
# real backend/uploads/ directory as a side effect of just importing the app.
os.environ["uploads_dir"] = tempfile.mkdtemp(prefix="vorrat-test-uploads-")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine, event  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.config import settings  # noqa: E402
from app.db import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.routers import products as products_router  # noqa: E402


@pytest.fixture()
def client(tmp_path, monkeypatch) -> Iterator[TestClient]:
    """A TestClient wired to a fresh, isolated SQLite database instead of the
    real vorrat.db. Uses an in-memory database on a StaticPool (a single
    shared connection) rather than a plain "sqlite://:memory:" engine --
    TestClient/FastAPI can hand a request to a different thread than the one
    that created the engine, and a plain in-memory engine hands each new
    connection its own separate, empty database, so StaticPool +
    check_same_thread=False is what keeps every request seeing the same data.

    Also redirects the products router's UPLOADS_DIR to a per-test tmp_path
    so product-photo routes never touch the real uploads/ directory (the
    module-level import-time redirect above only covers app startup, not
    each test's own isolation from one another). Tears down (drops the
    dependency override, disposes the engine) after every test so tests
    can't leak state into each other.
    """
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    @event.listens_for(engine, "connect")
    def _enable_sqlite_fk(dbapi_connection, _):
        dbapi_connection.execute("PRAGMA foreign_keys=ON")

    TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    Base.metadata.create_all(bind=engine)

    def _override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    uploads_dir = tmp_path / "uploads"
    uploads_dir.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(settings, "uploads_dir", str(uploads_dir))
    monkeypatch.setattr(products_router, "UPLOADS_DIR", uploads_dir)
    app.dependency_overrides[get_db] = _override_get_db
    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.pop(get_db, None)
        Base.metadata.drop_all(bind=engine)
        engine.dispose()

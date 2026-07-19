import sqlite3

from sqlalchemy import create_engine

from app.config import settings as env_settings
from app.routers import backup as backup_router


def _make_sqlite_file(path, marker):
    conn = sqlite3.connect(path)
    try:
        conn.execute("CREATE TABLE marker (value TEXT)")
        conn.execute("INSERT INTO marker (value) VALUES (?)", (marker,))
        conn.commit()
    finally:
        conn.close()


def _read_marker(path):
    conn = sqlite3.connect(path)
    try:
        return conn.execute("SELECT value FROM marker").fetchone()[0]
    finally:
        conn.close()


def test_download_backup_streams_a_point_in_time_snapshot(client, tmp_path, monkeypatch):
    db_path = tmp_path / "source.db"
    _make_sqlite_file(db_path, "hello")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{db_path}")

    response = client.get("/api/backup")

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/x-sqlite3"
    assert "vorrat-backup-" in response.headers["content-disposition"]

    downloaded = tmp_path / "downloaded.db"
    downloaded.write_bytes(response.content)
    assert _read_marker(downloaded) == "hello"


def test_download_backup_rejects_non_sqlite_database_url(client, monkeypatch):
    monkeypatch.setattr(env_settings, "database_url", "postgresql://localhost/vorrat")

    response = client.get("/api/backup")
    assert response.status_code == 501


def test_restore_backup_replaces_the_live_db_file(client, tmp_path, monkeypatch):
    target_path = tmp_path / "target.db"
    _make_sqlite_file(target_path, "old")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{target_path}")
    # backup.py imported `engine` by name from app.db, so patching
    # app.db.engine after the fact wouldn't be seen here -- the router's own
    # module-level reference has to be swapped instead.
    monkeypatch.setattr(backup_router, "engine", create_engine(f"sqlite:///{target_path}"))

    upload_path = tmp_path / "upload.db"
    _make_sqlite_file(upload_path, "new")

    with open(upload_path, "rb") as f:
        response = client.post(
            "/api/backup/restore",
            files={"file": ("upload.db", f, "application/x-sqlite3")},
        )

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert _read_marker(target_path) == "new"


def test_restore_backup_rejects_a_non_sqlite_upload(client, tmp_path, monkeypatch):
    target_path = tmp_path / "target2.db"
    _make_sqlite_file(target_path, "old")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{target_path}")

    response = client.post(
        "/api/backup/restore",
        files={"file": ("bad.db", b"not a sqlite database at all", "application/octet-stream")},
    )

    assert response.status_code == 400
    # The rejected upload must not have touched the existing live DB file.
    assert _read_marker(target_path) == "old"


def test_restore_backup_rejects_an_empty_upload(client, tmp_path, monkeypatch):
    # PRAGMA schema_version alone doesn't reject this -- SQLite treats an
    # empty file as a valid, freshly-initialized empty database -- so this
    # guards against an empty/truncated upload silently wiping the live DB.
    target_path = tmp_path / "target3.db"
    _make_sqlite_file(target_path, "old")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{target_path}")

    response = client.post(
        "/api/backup/restore",
        files={"file": ("empty.db", b"", "application/x-sqlite3")},
    )

    assert response.status_code == 400
    assert _read_marker(target_path) == "old"

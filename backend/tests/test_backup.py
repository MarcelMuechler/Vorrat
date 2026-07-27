import sqlite3

from alembic import command
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine

from app.config import settings as env_settings
from app.routers import backup as backup_router


def _head_revision():
    return ScriptDirectory.from_config(backup_router._alembic_config("sqlite://")).get_current_head()


def _make_sqlite_file(path, marker):
    conn = sqlite3.connect(path)
    try:
        conn.execute("CREATE TABLE marker (value TEXT)")
        conn.execute("INSERT INTO marker (value) VALUES (?)", (marker,))
        conn.commit()
    finally:
        conn.close()


def _make_vorrat_sqlite_file(path, marker, revision=None):
    # Like _make_sqlite_file, but also includes the tables restore_backup
    # requires as evidence the upload is actually a Vorrat backup, not just
    # any well-formed SQLite file -- the schema/columns don't matter for
    # that check, only that the tables exist.
    revision = revision or _head_revision()
    conn = sqlite3.connect(path)
    try:
        conn.execute("CREATE TABLE marker (value TEXT)")
        conn.execute("INSERT INTO marker (value) VALUES (?)", (marker,))
        conn.execute("CREATE TABLE products (id INTEGER PRIMARY KEY)")
        conn.execute("CREATE TABLE stock_entries (id INTEGER PRIMARY KEY)")
        # Restore also checks the schema revision (#326); claim head so this
        # helper keeps standing in for "a backup from this same version".
        conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)")
        conn.execute("INSERT INTO alembic_version (version_num) VALUES (?)", (revision,))
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
    _make_vorrat_sqlite_file(upload_path, "new")

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


def test_restore_backup_rejects_a_valid_but_foreign_sqlite_file(client, tmp_path, monkeypatch):
    # A well-formed SQLite file (passes the magic-header and
    # PRAGMA schema_version checks) that simply isn't a Vorrat backup --
    # e.g. an empty `sqlite3 empty.db "VACUUM"` or an unrelated app's
    # database -- must still be rejected rather than silently wiping the
    # live DB with data that has none of the expected tables.
    target_path = tmp_path / "target4.db"
    _make_sqlite_file(target_path, "old")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{target_path}")

    foreign_path = tmp_path / "foreign.db"
    conn = sqlite3.connect(foreign_path)
    try:
        conn.execute("CREATE TABLE unrelated_app_table (id INTEGER PRIMARY KEY)")
        conn.commit()
    finally:
        conn.close()

    with open(foreign_path, "rb") as f:
        response = client.post(
            "/api/backup/restore",
            files={"file": ("foreign.db", f, "application/x-sqlite3")},
        )

    assert response.status_code == 400
    assert "not a Vorrat backup" in response.json()["detail"]
    # The rejected upload must not have touched the existing live DB file.
    assert _read_marker(target_path) == "old"


def test_restore_backup_migrates_an_older_schema_backup(client, tmp_path, monkeypatch):
    # Migrations only ever run at container start, so an older backup restored
    # mid-process used to leave the running code querying columns that don't
    # exist yet -- a 500 on the stock overview right after a "restore ok"
    # (#326). The upload is migrated to head before the swap instead.
    target_path = tmp_path / "target5.db"
    _make_vorrat_sqlite_file(target_path, "old")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{target_path}")
    monkeypatch.setattr(backup_router, "engine", create_engine(f"sqlite:///{target_path}"))

    # A genuine old-schema database, built by running the real migrations up
    # to the revision just before head.
    script = ScriptDirectory.from_config(backup_router._alembic_config("sqlite://"))
    head = script.get_current_head()
    previous = script.get_revision(head).down_revision
    upload_path = tmp_path / "upload_old.db"
    command.upgrade(backup_router._alembic_config(f"sqlite:///{upload_path}"), previous)

    with open(upload_path, "rb") as f:
        response = client.post(
            "/api/backup/restore",
            files={"file": ("upload.db", f, "application/x-sqlite3")},
        )

    assert response.status_code == 200
    conn = sqlite3.connect(target_path)
    try:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == head
    finally:
        conn.close()


def test_restore_backup_rejects_an_unknown_schema_revision(client, tmp_path, monkeypatch):
    # A backup from a *newer* Vorrat (restored after a rollback) has no
    # downgrade path, so it must be refused rather than swapped in.
    target_path = tmp_path / "target6.db"
    _make_vorrat_sqlite_file(target_path, "old")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{target_path}")

    upload_path = tmp_path / "upload_future.db"
    _make_vorrat_sqlite_file(upload_path, "new", revision="f00dfeed1234")

    with open(upload_path, "rb") as f:
        response = client.post(
            "/api/backup/restore",
            files={"file": ("upload.db", f, "application/x-sqlite3")},
        )

    assert response.status_code == 400
    assert "f00dfeed1234" in response.json()["detail"]
    assert _read_marker(target_path) == "old"

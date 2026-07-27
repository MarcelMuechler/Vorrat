import io
import sqlite3
import zipfile

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


def test_download_backup_ships_the_db_and_the_uploaded_photos(client, tmp_path, monkeypatch):
    # #325: photos live outside the db (referenced only as /uploads/<file>),
    # so a db-only backup restored every product with a broken image.
    db_path = tmp_path / "source.db"
    _make_sqlite_file(db_path, "hello")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{db_path}")
    # The client fixture already points uploads_dir at tmp_path/uploads.
    (tmp_path / "uploads" / "7-abc123.jpg").write_bytes(b"photo-bytes")

    response = client.get("/api/backup")

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/zip"
    assert "vorrat-backup-" in response.headers["content-disposition"]
    assert response.headers["content-disposition"].endswith('.zip"')

    archive = zipfile.ZipFile(io.BytesIO(response.content))
    assert archive.read("uploads/7-abc123.jpg") == b"photo-bytes"
    downloaded = tmp_path / "downloaded.db"
    downloaded.write_bytes(archive.read("vorrat.db"))
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


def _make_backup_zip(path, db_source, photos):
    with zipfile.ZipFile(path, "w") as archive:
        archive.write(db_source, "vorrat.db")
        for name, content in photos.items():
            archive.writestr(f"uploads/{name}", content)


def test_restore_backup_accepts_a_zip_and_restores_the_photos(client, tmp_path, monkeypatch):
    target_path = tmp_path / "target7.db"
    _make_sqlite_file(target_path, "old")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{target_path}")
    monkeypatch.setattr(backup_router, "engine", create_engine(f"sqlite:///{target_path}"))

    inner_db = tmp_path / "inner.db"
    _make_vorrat_sqlite_file(inner_db, "new")
    zip_path = tmp_path / "backup.zip"
    _make_backup_zip(zip_path, inner_db, {"7-abc123.jpg": b"photo-bytes"})

    with open(zip_path, "rb") as f:
        response = client.post(
            "/api/backup/restore",
            files={"file": ("backup.zip", f, "application/zip")},
        )

    assert response.status_code == 200
    assert _read_marker(target_path) == "new"
    assert (tmp_path / "uploads" / "7-abc123.jpg").read_bytes() == b"photo-bytes"


def test_restore_backup_zip_cannot_write_outside_the_uploads_dir(client, tmp_path, monkeypatch):
    # Only the basename of each uploads/ member is used, so a crafted archive
    # can't traverse out of the uploads directory.
    target_path = tmp_path / "target8.db"
    _make_sqlite_file(target_path, "old")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{target_path}")
    monkeypatch.setattr(backup_router, "engine", create_engine(f"sqlite:///{target_path}"))

    inner_db = tmp_path / "inner2.db"
    _make_vorrat_sqlite_file(inner_db, "new")
    zip_path = tmp_path / "evil.zip"
    _make_backup_zip(zip_path, inner_db, {"../../escaped.txt": b"nope"})

    with open(zip_path, "rb") as f:
        response = client.post(
            "/api/backup/restore",
            files={"file": ("backup.zip", f, "application/zip")},
        )

    assert response.status_code == 200
    assert not (tmp_path / "escaped.txt").exists()
    assert (tmp_path / "uploads" / "escaped.txt").read_bytes() == b"nope"


def test_restore_backup_rejects_a_zip_without_a_database(client, tmp_path, monkeypatch):
    target_path = tmp_path / "target9.db"
    _make_sqlite_file(target_path, "old")
    monkeypatch.setattr(env_settings, "database_url", f"sqlite:///{target_path}")

    zip_path = tmp_path / "photos-only.zip"
    with zipfile.ZipFile(zip_path, "w") as archive:
        archive.writestr("uploads/1-a.jpg", b"photo")

    with open(zip_path, "rb") as f:
        response = client.post(
            "/api/backup/restore",
            files={"file": ("backup.zip", f, "application/zip")},
        )

    assert response.status_code == 400
    assert _read_marker(target_path) == "old"

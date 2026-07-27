import os
import sqlite3
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask

from app.config import settings as env_settings
from app.db import engine

router = APIRouter(prefix="/api/backup", tags=["backup"])

# A restore uploads a whole SQLite file, not a small form payload -- generous
# but bounded so a misbehaving/hostile client can't fill the disk via an
# unbounded upload (mirrors stock.py's IMPORT_CSV_MAX_BYTES pattern).
_MAX_RESTORE_BYTES = 500 * 1024 * 1024
_SQLITE_HEADER = b"SQLite format 3\x00"
# Tables that must exist for an uploaded file to plausibly be a Vorrat
# backup rather than just any well-formed SQLite file -- an empty or
# foreign database (e.g. a fresh `sqlite3 x.db "VACUUM"`) passes the magic
# header and PRAGMA schema_version checks below but has neither of these,
# and would otherwise silently wipe the live DB via os.replace.
_REQUIRED_TABLES = ("products", "stock_entries", "alembic_version")

# backend/alembic, from backend/app/routers/backup.py -- the same directory
# the container's start-up `alembic upgrade head` uses.
_ALEMBIC_DIR = Path(__file__).resolve().parents[2] / "alembic"


def _alembic_config(db_url: str) -> Config:
    """A Config with no .ini file on purpose: env.py only calls
    `fileConfig(config.config_file_name)` when there is one, and that would
    reconfigure (and by default disable) the running server's loggers."""
    config = Config()
    config.set_main_option("script_location", str(_ALEMBIC_DIR))
    config.attributes["db_url"] = db_url
    return config


def _db_path() -> str:
    # database_url is "sqlite:///relative/path" or "sqlite:////absolute/path"
    # (the fourth slash, when present, is the leading "/" of an absolute
    # path) -- mirrors how db.py hands the same URL to SQLAlchemy.
    if not env_settings.database_url.startswith("sqlite"):
        raise HTTPException(status_code=501, detail="Backup/restore only supports SQLite databases")
    return env_settings.database_url.split("///", 1)[1]


@router.get("")
def download_backup():
    """Streams a point-in-time snapshot of the live DB, taken via sqlite3's
    backup API rather than copying the file directly -- a plain file copy
    could race a concurrent writer and ship a torn/corrupt snapshot."""
    fd, tmp_path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    source = sqlite3.connect(_db_path())
    try:
        target = sqlite3.connect(tmp_path)
        try:
            source.backup(target)
        finally:
            target.close()
    finally:
        source.close()
    filename = f"vorrat-backup-{datetime.now(timezone.utc):%Y%m%d-%H%M%S}.db"
    return FileResponse(
        tmp_path,
        media_type="application/x-sqlite3",
        filename=filename,
        background=BackgroundTask(os.unlink, tmp_path),
    )


@router.post("/restore")
def restore_backup(file: UploadFile = File(...)):
    """Replaces the live DB file with the upload. A backup taken from an
    older schema version is migrated up to head *before* the swap (#326) --
    migrations otherwise only run at container start, so an old backup
    restored mid-process would leave the running code querying columns that
    don't exist yet. Migrating the upload rather than the live file means a
    migration that fails leaves the live database untouched.

    A plain `def`, not `async def`, like download_backup above -- everything
    this does (file copy, sqlite3 connect, engine.dispose(), os.replace) is
    blocking, and FastAPI runs a sync route in a threadpool automatically,
    where an `async def` doing the same blocking work would instead run
    directly on the event loop and stall every other in-flight request for
    the duration of the restore."""
    target_path = _db_path()
    target_dir = os.path.dirname(os.path.abspath(target_path)) or "."
    fd, tmp_path = tempfile.mkstemp(dir=target_dir, suffix=".upload")
    try:
        with os.fdopen(fd, "wb") as out:
            written = 0
            while chunk := file.file.read(1024 * 1024):
                written += len(chunk)
                if written > _MAX_RESTORE_BYTES:
                    raise HTTPException(status_code=413, detail="Backup upload too large")
                out.write(chunk)

        # A quick magic-bytes check first: PRAGMA schema_version alone
        # doesn't reject this -- SQLite treats an empty/all-zero file as a
        # valid, freshly-initialized empty database, so an empty or
        # truncated upload would otherwise sail through and silently replace
        # the live DB with an empty one.
        with open(tmp_path, "rb") as f:
            header = f.read(len(_SQLITE_HEADER))
        if header != _SQLITE_HEADER:
            raise HTTPException(status_code=400, detail="Uploaded file is not a valid SQLite database")
        try:
            check = sqlite3.connect(tmp_path)
            try:
                check.execute("PRAGMA schema_version")
                existing_tables = {
                    row[0]
                    for row in check.execute(
                        "SELECT name FROM sqlite_master WHERE type = 'table'"
                    )
                }
                uploaded_revision = None
                if "alembic_version" in existing_tables:
                    row = check.execute("SELECT version_num FROM alembic_version").fetchone()
                    uploaded_revision = row[0] if row else None
            finally:
                check.close()
        except sqlite3.DatabaseError:
            raise HTTPException(status_code=400, detail="Uploaded file is not a valid SQLite database")

        missing_tables = [t for t in _REQUIRED_TABLES if t not in existing_tables]
        if missing_tables:
            # Distinct from the generic "not a valid SQLite database" error
            # above: this file *is* a well-formed SQLite database, it's just
            # not a Vorrat one (e.g. empty, or from an unrelated app).
            raise HTTPException(
                status_code=400,
                detail=(
                    "Uploaded file is a valid SQLite database but not a Vorrat backup "
                    f"(missing expected table(s): {', '.join(missing_tables)})"
                ),
            )

        config = _alembic_config(f"sqlite:///{tmp_path}")
        script = ScriptDirectory.from_config(config)
        head = script.get_current_head()
        if uploaded_revision != head:
            # walk_revisions() only yields head and its ancestors, so
            # membership is exactly "this app knows how to upgrade it".
            # Anything else -- a revision from a newer Vorrat (no downgrade
            # path exists) or from an unrelated history -- is rejected rather
            # than swapped in for the running code to choke on.
            if uploaded_revision not in {rev.revision for rev in script.walk_revisions()}:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f"Backup was taken at schema revision {uploaded_revision or 'unknown'}, "
                        f"which this version of Vorrat doesn't know (it expects {head}). "
                        "Restore it on the version it came from, or update Vorrat first."
                    ),
                )
            command.upgrade(config, "head")

        # Drop the pool's open connections to the old file first -- otherwise
        # the swap below can leave a writer holding a handle to the replaced
        # (now unlinked) file. SQLAlchemy reconnects lazily on next use.
        engine.dispose()
        os.replace(tmp_path, target_path)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
    return {"status": "ok"}

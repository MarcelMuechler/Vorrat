import csv
import io
from datetime import date, datetime, time, timedelta, timezone

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session, contains_eager

from app.db import get_db
from app.models import ConsumptionLog, Product
from app.schemas import ConsumptionLogItem, ConsumptionLogRead
from app.utils import escape_csv_formula_injection

router = APIRouter(prefix="/api/consumption-log", tags=["consumption-log"])


def _local_midnight_utc(d: date) -> datetime:
    """Converts a local calendar-day boundary to the naive UTC datetime
    ConsumptionLog.created_at can be compared against -- created_at is
    written via SQLite's CURRENT_TIMESTAMP (naive UTC), but since/until are
    local calendar dates (what a date picker or `date.today()` produces).
    Comparing them directly was wrong for part of the day whenever the local
    and UTC calendar dates differ (e.g. shortly after local midnight in any
    UTC+ timezone), silently including/excluding entries by up to a day.
    `.astimezone()` with no args reinterprets a naive datetime as the
    system's local time, so this also accounts for DST on that date."""
    return datetime.combine(d, time.min).astimezone(timezone.utc).replace(tzinfo=None)


def _query_consumption_log(
    db: Session,
    since: date | None = None,
    until: date | None = None,
    reason: str | None = None,
) -> list[ConsumptionLogItem]:
    query = (
        db.query(ConsumptionLog)
        .join(Product)
        .options(contains_eager(ConsumptionLog.product))
    )
    if since is not None:
        query = query.filter(ConsumptionLog.created_at >= _local_midnight_utc(since))
    if until is not None:
        query = query.filter(
            ConsumptionLog.created_at < _local_midnight_utc(until + timedelta(days=1))
        )
    if reason is not None:
        query = query.filter(ConsumptionLog.reason == reason)
    return [
        ConsumptionLogItem(
            **ConsumptionLogRead.model_validate(entry).model_dump(),
            product_name=entry.product.name,
        )
        for entry in query.order_by(ConsumptionLog.created_at.desc()).all()
    ]


@router.get("", response_model=list[ConsumptionLogItem])
def list_consumption_log(
    since: date | None = None,
    until: date | None = None,
    reason: str | None = None,
    db: Session = Depends(get_db),
):
    return _query_consumption_log(db, since, until, reason)


@router.get("/export.csv")
def export_consumption_log_csv(
    since: date | None = None,
    until: date | None = None,
    reason: str | None = None,
    db: Session = Depends(get_db),
):
    output = io.StringIO()
    writer = csv.writer(output)
    # price is the per-unit price snapshotted at consume/spoil time (see
    # ConsumptionLog.price) -- without it the export can't answer "how much
    # money did I throw away", which is the point of tracking waste (#321).
    writer.writerow(["created_at", "product_name", "amount", "quantity_unit", "reason", "price"])
    for item in _query_consumption_log(db, since, until, reason):
        writer.writerow(
            [
                item.created_at,
                escape_csv_formula_injection(item.product_name),
                item.amount,
                escape_csv_formula_injection(item.quantity_unit or ""),
                escape_csv_formula_injection(item.reason),
                "" if item.price is None else item.price,
            ]
        )
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=consumption_log.csv"},
    )

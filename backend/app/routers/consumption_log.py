import csv
import io
from datetime import date, timedelta

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session, contains_eager

from app.db import get_db
from app.models import ConsumptionLog, Product
from app.schemas import ConsumptionLogItem, ConsumptionLogRead

router = APIRouter(prefix="/api/consumption-log", tags=["consumption-log"])


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
        query = query.filter(ConsumptionLog.created_at >= since)
    if until is not None:
        query = query.filter(ConsumptionLog.created_at < until + timedelta(days=1))
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
    writer.writerow(["created_at", "product_name", "amount", "quantity_unit", "reason"])
    for item in _query_consumption_log(db, since, until, reason):
        writer.writerow(
            [item.created_at, item.product_name, item.amount, item.quantity_unit or "", item.reason]
        )
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=consumption_log.csv"},
    )

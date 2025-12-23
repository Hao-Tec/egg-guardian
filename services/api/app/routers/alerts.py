"""Alerts router for viewing and managing triggered alerts."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone

from app.database import get_db
from app.models import Alert, Device
from app.schemas import AlertResponse


router = APIRouter(prefix="/api/v1/alerts", tags=["Alerts"])


@router.get("", response_model=list[AlertResponse])
async def list_alerts(
    db: AsyncSession = Depends(get_db),
    limit: int = 50,
    unacknowledged_only: bool = False,
):
    """List all alerts, optionally filtering by acknowledgment status."""
    query = select(Alert).order_by(Alert.triggered_at.desc()).limit(limit)
    if unacknowledged_only:
        query = query.where(Alert.is_acknowledged == False)
    
    result = await db.execute(query)
    alerts = result.scalars().all()
    return alerts


@router.get("/{alert_id}", response_model=AlertResponse)
async def get_alert(
    alert_id: int,
    db: AsyncSession = Depends(get_db),
):
    """Get a specific alert by ID."""
    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found",
        )
    return alert


@router.patch("/{alert_id}/acknowledge", response_model=AlertResponse)
async def acknowledge_alert(
    alert_id: int,
    db: AsyncSession = Depends(get_db),
):
    """Acknowledge an alert."""
    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found",
        )
    
    alert.is_acknowledged = True
    alert.acknowledged_at = datetime.now(timezone.utc)
    await db.flush()
    await db.refresh(alert)
    return alert


@router.patch("/acknowledge-all", status_code=status.HTTP_200_OK)
async def acknowledge_all_alerts(
    db: AsyncSession = Depends(get_db),
):
    """Acknowledge all unacknowledged alerts."""
    result = await db.execute(
        select(Alert).where(Alert.is_acknowledged == False)
    )
    alerts = result.scalars().all()
    
    now = datetime.now(timezone.utc)
    for alert in alerts:
        alert.is_acknowledged = True
        alert.acknowledged_at = now
    
    await db.flush()
    return {"acknowledged": len(alerts)}


@router.get("/device/{device_id}", response_model=list[AlertResponse])
async def list_device_alerts(
    device_id: int,
    db: AsyncSession = Depends(get_db),
    limit: int = 20,
):
    """List alerts for a specific device."""
    # Verify device exists
    device_result = await db.execute(select(Device).where(Device.id == device_id))
    if not device_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
    
    result = await db.execute(
        select(Alert)
        .where(Alert.device_id == device_id)
        .order_by(Alert.triggered_at.desc())
        .limit(limit)
    )
    alerts = result.scalars().all()
    return alerts


@router.delete("/clear-acknowledged", status_code=status.HTTP_200_OK)
async def clear_acknowledged_alerts(
    db: AsyncSession = Depends(get_db),
):
    """Delete all acknowledged alerts to clean up history."""
    result = await db.execute(
        select(Alert).where(Alert.is_acknowledged == True)
    )
    alerts = result.scalars().all()
    
    count = len(alerts)
    for alert in alerts:
        await db.delete(alert)
    
    await db.flush()
    return {"deleted": count}


@router.delete("/delete-all", status_code=status.HTTP_200_OK)
async def delete_all_alerts(
    db: AsyncSession = Depends(get_db),
):
    """Delete ALL alerts (acknowledged and unacknowledged)."""
    result = await db.execute(select(Alert))
    alerts = result.scalars().all()
    
    count = len(alerts)
    for alert in alerts:
        await db.delete(alert)
    
    await db.flush()
    return {"deleted": count}

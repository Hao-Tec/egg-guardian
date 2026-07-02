"""Alerts router for viewing and managing triggered alerts."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone

from app.database import get_db
from app.models import Alert, Device, User
from app.schemas import AlertResponse
from app.services.deps import get_current_user


router = APIRouter(prefix="/api/v1/alerts", tags=["Alerts"])


def check_alert_access(alert: Alert, current_user: User, db: AsyncSession = None):
    # This requires looking up the device if the alert doesn't contain owner_id,
    # but we can do that within the endpoint queries more efficiently.
    pass


@router.get("", response_model=list[AlertResponse])
async def list_alerts(
    db: AsyncSession = Depends(get_db),
    limit: int = 50,
    unacknowledged_only: bool = False,
    current_user: User = Depends(get_current_user),
):
    """List all alerts (authenticated)."""
    query = select(Alert).join(Device, Alert.device_id == Device.id)
    
    if not current_user.is_superuser:
        query = query.where(Device.owner_id == current_user.id)
        
    query = query.order_by(Alert.triggered_at.desc()).limit(limit)
    
    if unacknowledged_only:
        query = query.where(Alert.is_acknowledged == False)

    result = await db.execute(query)
    alerts = result.scalars().all()
    return alerts


@router.get("/{alert_id}", response_model=AlertResponse)
async def get_alert(
    alert_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a specific alert by ID."""
    query = select(Alert).join(Device, Alert.device_id == Device.id).where(Alert.id == alert_id)
    if not current_user.is_superuser:
        query = query.where(Device.owner_id == current_user.id)
        
    result = await db.execute(query)
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found or unauthorized",
        )
    return alert


@router.patch("/{alert_id}/acknowledge", response_model=AlertResponse)
async def acknowledge_alert(
    alert_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Acknowledge an alert."""
    query = select(Alert).join(Device, Alert.device_id == Device.id).where(Alert.id == alert_id)
    if not current_user.is_superuser:
        query = query.where(Device.owner_id == current_user.id)
        
    result = await db.execute(query)
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found or unauthorized",
        )

    alert.is_acknowledged = True
    alert.acknowledged_at = datetime.now(timezone.utc)
    await db.flush()
    await db.refresh(alert)
    return alert


@router.patch("/acknowledge-all", status_code=status.HTTP_200_OK)
async def acknowledge_all_alerts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Acknowledge all unacknowledged alerts for the user's devices."""
    query = select(Alert).join(Device, Alert.device_id == Device.id).where(Alert.is_acknowledged == False)
    if not current_user.is_superuser:
        query = query.where(Device.owner_id == current_user.id)
        
    result = await db.execute(query)
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
    current_user: User = Depends(get_current_user),
):
    """List alerts for a specific device."""
    device_result = await db.execute(select(Device).where(Device.id == device_id))
    device = device_result.scalar_one_or_none()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
        
    if not current_user.is_superuser and device.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this device's alerts",
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
    current_user: User = Depends(get_current_user),
):
    """Delete all acknowledged alerts (authenticated & authorized)."""
    query = select(Alert).join(Device, Alert.device_id == Device.id).where(Alert.is_acknowledged == True)
    if not current_user.is_superuser:
        query = query.where(Device.owner_id == current_user.id)
        
    result = await db.execute(query)
    alerts = result.scalars().all()

    count = len(alerts)
    for alert in alerts:
        await db.delete(alert)

    await db.flush()
    return {"deleted": count}


@router.delete("/delete-all", status_code=status.HTTP_200_OK)
async def delete_all_alerts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete ALL alerts (authenticated & authorized)."""
    query = select(Alert).join(Device, Alert.device_id == Device.id)
    if not current_user.is_superuser:
        query = query.where(Device.owner_id == current_user.id)
        
    result = await db.execute(query)
    alerts = result.scalars().all()

    count = len(alerts)
    for alert in alerts:
        await db.delete(alert)

    await db.flush()
    return {"deleted": count}

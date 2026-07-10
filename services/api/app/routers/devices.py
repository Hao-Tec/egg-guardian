"""Device management router."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import AlertRule, Device, User
from app.schemas import (
    AlertRuleCreate,
    AlertRuleResponse,
    DeviceCreate,
    DeviceResponse,
    DeviceUpdate,
)
from app.services.deps import get_current_user, get_current_superuser

router = APIRouter(prefix="/api/v1/devices", tags=["Devices"])


def check_device_access(device: Device, current_user: User):
    """Check if the current user has access to the device."""
    if not current_user.is_superuser and device.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this device",
        )


@router.get("", response_model=list[DeviceResponse])
async def list_devices(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all devices with their latest telemetry (authenticated)."""
    from sqlalchemy import func
    from app.models import Telemetry, AlertRule

    query = select(Device).order_by(Device.created_at.desc())

    result = await db.execute(query)
    devices = result.scalars().all()

    for device in devices:
        telemetry_result = await db.execute(
            select(Telemetry)
            .where(Telemetry.device_id == device.id)
            .order_by(Telemetry.recorded_at.desc())
            .limit(1)
        )
        latest = telemetry_result.scalar_one_or_none()
        if latest:
            device.last_temp = latest.temp_c
            device.last_recorded_at = latest.recorded_at

        # Fetch active alert rule for threshold data
        rule_result = await db.execute(
            select(AlertRule)
            .where(AlertRule.device_id == device.id, AlertRule.is_active == True)
            .limit(1)
        )
        rule = rule_result.scalar_one_or_none()
        device.temp_min = rule.temp_min if rule else 35.0
        device.temp_max = rule.temp_max if rule else 39.0

    return devices


@router.post("", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
async def create_device(
    device_data: DeviceCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser),
):
    """Register a new device (superuser only)."""
    existing = await db.execute(
        select(Device).where(Device.device_id == device_data.device_id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Device with ID '{device_data.device_id}' already exists",
        )

    device = Device(
        device_id=device_data.device_id,
        name=device_data.name,
        description=device_data.description,
        owner_id=current_user.id,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)
    return device


@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a specific device by ID."""
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
    # Removed check_device_access to allow all users to view the device
    
    from app.models import AlertRule
    rule_result = await db.execute(
        select(AlertRule)
        .where(AlertRule.device_id == device.id, AlertRule.is_active == True)
        .limit(1)
    )
    rule = rule_result.scalar_one_or_none()
    device.temp_min = rule.temp_min if rule else 35.0
    device.temp_max = rule.temp_max if rule else 39.0
    
    return device


@router.patch("/{device_id}", response_model=DeviceResponse)
async def update_device(
    device_id: int,
    device_data: DeviceUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update a device (authenticated)."""
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
    check_device_access(device, current_user)

    if device_data.name is not None:
        device.name = device_data.name
    if device_data.description is not None:
        device.description = device_data.description
    if device_data.is_active is not None:
        device.is_active = device_data.is_active

    await db.flush()
    await db.refresh(device)
    return device


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(
    device_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a device (authenticated)."""
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
    check_device_access(device, current_user)
    await db.delete(device)


# ============== Alert Rules ==============


@router.get("/rules/all", response_model=list[AlertRuleResponse])
async def list_all_rules(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all alert rules (bulk fetch)."""
    query = select(AlertRule, Device.name).join(Device, AlertRule.device_id == Device.id)
    if not current_user.is_superuser:
        query = query.where(Device.owner_id == current_user.id)
    query = query.order_by(Device.name, AlertRule.id)

    result = await db.execute(query)
    rules = []
    for rule, device_name in result.all():
        rule_dict = {
            "id": rule.id,
            "device_id": rule.device_id,
            "temp_min": rule.temp_min,
            "temp_max": rule.temp_max,
            "is_active": rule.is_active,
            "created_at": rule.created_at,
            "device_name": device_name,
        }
        rules.append(rule_dict)
    return rules


@router.get("/{device_id}/rules", response_model=list[AlertRuleResponse])
async def list_device_rules(
    device_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List alert rules for a device."""
    device_result = await db.execute(select(Device).where(Device.id == device_id))
    device = device_result.scalar_one_or_none()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
    # Allow all authenticated users to read rules

    result = await db.execute(select(AlertRule).where(AlertRule.device_id == device_id))
    return result.scalars().all()


@router.post(
    "/{device_id}/rules",
    response_model=AlertRuleResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_device_rule(
    device_id: int,
    rule_data: AlertRuleCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create an alert rule for a device."""
    device_result = await db.execute(select(Device).where(Device.id == device_id))
    device = device_result.scalar_one_or_none()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
    check_device_access(device, current_user)

    if rule_data.temp_min >= rule_data.temp_max:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="temp_min must be less than temp_max",
        )

    rule = AlertRule(
        device_id=device_id,
        temp_min=rule_data.temp_min,
        temp_max=rule_data.temp_max,
    )
    db.add(rule)
    await db.flush()
    await db.refresh(rule)
    return rule


@router.delete("/{device_id}/rules/{rule_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device_rule(
    device_id: int,
    rule_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete an alert rule."""
    device_result = await db.execute(select(Device).where(Device.id == device_id))
    device = device_result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    check_device_access(device, current_user)

    result = await db.execute(
        select(AlertRule).where(
            AlertRule.id == rule_id,
            AlertRule.device_id == device_id,
        )
    )
    rule = result.scalar_one_or_none()
    if not rule:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert rule not found",
        )

    await db.delete(rule)

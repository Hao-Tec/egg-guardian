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
from app.services.deps import get_current_user, get_optional_user

router = APIRouter(prefix="/api/v1/devices", tags=["Devices"])


@router.get("", response_model=list[DeviceResponse])
async def list_devices(
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """List all devices (public endpoint for MVP)."""
    result = await db.execute(select(Device).order_by(Device.created_at.desc()))
    devices = result.scalars().all()
    return devices


@router.post("", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
async def create_device(
    device_data: DeviceCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Register a new device."""
    # Check if device_id already exists
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
        owner_id=current_user.id if current_user else None,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)
    return device


@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: int,
    db: AsyncSession = Depends(get_db),
):
    """Get a specific device by ID."""
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
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

    # Update fields
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

    await db.delete(device)


# ============== Alert Rules ==============

@router.get("/{device_id}/rules", response_model=list[AlertRuleResponse])
async def list_device_rules(
    device_id: int,
    db: AsyncSession = Depends(get_db),
):
    """List alert rules for a device."""
    # Verify device exists
    device_result = await db.execute(select(Device).where(Device.id == device_id))
    if not device_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )

    result = await db.execute(
        select(AlertRule).where(AlertRule.device_id == device_id)
    )
    return result.scalars().all()


@router.post("/{device_id}/rules", response_model=AlertRuleResponse, status_code=status.HTTP_201_CREATED)
async def create_device_rule(
    device_id: int,
    rule_data: AlertRuleCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create an alert rule for a device."""
    # Verify device exists
    device_result = await db.execute(select(Device).where(Device.id == device_id))
    if not device_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )

    # Validate min < max
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
):
    """Delete an alert rule."""
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

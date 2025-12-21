"""Telemetry router with history and WebSocket endpoints."""

import asyncio
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Device, Telemetry
from app.schemas import TelemetryHistory, TelemetryResponse

router = APIRouter(prefix="/api/v1", tags=["Telemetry"])

# WebSocket connection manager
class ConnectionManager:
    """Manages WebSocket connections per device."""

    def __init__(self):
        self.active_connections: dict[str, list[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, device_id: str):
        await websocket.accept()
        if device_id not in self.active_connections:
            self.active_connections[device_id] = []
        self.active_connections[device_id].append(websocket)

    def disconnect(self, websocket: WebSocket, device_id: str):
        if device_id in self.active_connections:
            self.active_connections[device_id].remove(websocket)
            if not self.active_connections[device_id]:
                del self.active_connections[device_id]

    async def broadcast_to_device(self, device_id: str, message: dict):
        """Broadcast message to all connections watching a device."""
        if device_id in self.active_connections:
            for connection in self.active_connections[device_id]:
                try:
                    await connection.send_json(message)
                except Exception:
                    pass  # Connection may be closed

    async def broadcast_all(self, message: dict):
        """Broadcast to all connections."""
        for device_id in self.active_connections:
            await self.broadcast_to_device(device_id, message)


# Global connection manager
manager = ConnectionManager()


def get_connection_manager() -> ConnectionManager:
    """Get the WebSocket connection manager."""
    return manager


@router.get("/devices/{device_id}/telemetry", response_model=TelemetryHistory)
async def get_device_telemetry(
    device_id: int,
    hours: int = Query(default=24, ge=1, le=168),
    limit: int = Query(default=1000, ge=1, le=10000),
    db: AsyncSession = Depends(get_db),
):
    """Get telemetry history for a device."""
    # Get device
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )

    # Get telemetry within time window
    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    telemetry_result = await db.execute(
        select(Telemetry)
        .where(Telemetry.device_id == device_id)
        .where(Telemetry.recorded_at >= since)
        .order_by(Telemetry.recorded_at.desc())
        .limit(limit)
    )
    readings = telemetry_result.scalars().all()

    return TelemetryHistory(
        device_id=device.device_id,
        device_name=device.name,
        readings=[TelemetryResponse.model_validate(r) for r in readings],
        count=len(readings),
    )


@router.websocket("/ws/{device_id}")
async def websocket_endpoint(
    websocket: WebSocket,
    device_id: str,
):
    """
    WebSocket endpoint for real-time telemetry updates.
    
    Connect to receive telemetry and alert updates for a specific device.
    Use device_id="all" to receive updates for all devices.
    """
    await manager.connect(websocket, device_id)
    try:
        # Send initial connection success message
        await websocket.send_json({
            "type": "connected",
            "device_id": device_id,
            "message": f"Connected to telemetry stream for {device_id}",
        })

        # Keep connection alive and listen for messages
        while True:
            try:
                # Wait for client messages (ping/pong or commands)
                data = await asyncio.wait_for(
                    websocket.receive_json(),
                    timeout=30.0  # 30 second timeout for keepalive
                )
                
                # Handle ping
                if data.get("type") == "ping":
                    await websocket.send_json({"type": "pong"})
                    
            except asyncio.TimeoutError:
                # Send keepalive ping
                await websocket.send_json({"type": "ping"})
                
    except WebSocketDisconnect:
        manager.disconnect(websocket, device_id)
    except Exception:
        manager.disconnect(websocket, device_id)

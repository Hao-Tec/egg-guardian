"""MQTT service for ingesting telemetry from devices."""

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Optional

from aiomqtt import Client, MqttError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import async_session_maker
from app.models import Alert, AlertRule, Device, Telemetry
from app.routers.telemetry import get_connection_manager

logger = logging.getLogger(__name__)
settings = get_settings()


class MQTTService:
    """MQTT client service for telemetry ingestion."""

    def __init__(self):
        self.running = False
        self._task: Optional[asyncio.Task] = None

    async def start(self):
        """Start the MQTT subscription service."""
        if self.running:
            return
        self.running = True
        self._task = asyncio.create_task(self._run())
        logger.info("MQTT service started")

    async def stop(self):
        """Stop the MQTT subscription service."""
        self.running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("MQTT service stopped")

    async def _run(self):
        """Main MQTT subscription loop with reconnection."""
        while self.running:
            try:
                async with Client(
                    settings.mqtt_broker,
                    port=settings.mqtt_port,
                ) as client:
                    # Subscribe to all device telemetry topics
                    await client.subscribe("egg/+/telemetry")
                    logger.info(f"Subscribed to egg/+/telemetry on {settings.mqtt_broker}:{settings.mqtt_port}")

                    async for message in client.messages:
                        if not self.running:
                            break
                        try:
                            await self._handle_message(message)
                        except Exception as e:
                            logger.error(f"Error handling message: {e}")

            except MqttError as e:
                logger.error(f"MQTT connection error: {e}")
                if self.running:
                    await asyncio.sleep(5)  # Wait before reconnecting
            except Exception as e:
                logger.error(f"Unexpected error in MQTT service: {e}")
                if self.running:
                    await asyncio.sleep(5)

    async def _handle_message(self, message):
        """Process incoming MQTT message."""
        try:
            # Parse topic to extract device_id
            topic_parts = message.topic.value.split("/")
            if len(topic_parts) != 3 or topic_parts[0] != "egg" or topic_parts[2] != "telemetry":
                logger.warning(f"Invalid topic format: {message.topic}")
                return

            mqtt_device_id = topic_parts[1]

            # Parse payload
            payload = json.loads(message.payload.decode())
            device_id = payload.get("device_id", mqtt_device_id)
            temp_c = float(payload["temp_c"])
            
            # Parse timestamp
            ts_str = payload.get("ts")
            if ts_str:
                recorded_at = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            else:
                recorded_at = datetime.now(timezone.utc)

            logger.debug(f"Received telemetry: device={device_id}, temp={temp_c}°C")

            # Persist to database
            async with async_session_maker() as db:
                await self._persist_telemetry(db, device_id, temp_c, recorded_at)
                await db.commit()

        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON payload: {e}")
        except KeyError as e:
            logger.error(f"Missing required field: {e}")
        except Exception as e:
            logger.error(f"Error processing telemetry: {e}")

    async def _persist_telemetry(
        self,
        db: AsyncSession,
        device_id: str,
        temp_c: float,
        recorded_at: datetime,
    ):
        """Persist telemetry to database and check alerts."""
        # Get or create device
        result = await db.execute(
            select(Device).where(Device.device_id == device_id)
        )
        device = result.scalar_one_or_none()

        if not device:
            # Auto-register device if it doesn't exist
            device = Device(
                device_id=device_id,
                name=f"Auto-registered: {device_id}",
            )
            db.add(device)
            await db.flush()
            logger.info(f"Auto-registered device: {device_id}")

        # Create telemetry record
        telemetry = Telemetry(
            device_id=device.id,
            temp_c=temp_c,
            recorded_at=recorded_at,
        )
        db.add(telemetry)
        await db.flush()

        # Broadcast to WebSocket clients
        ws_manager = get_connection_manager()
        await ws_manager.broadcast_to_device(device_id, {
            "type": "telemetry",
            "device_id": device_id,
            "data": {
                "temp_c": temp_c,
                "recorded_at": recorded_at.isoformat(),
            },
        })
        # Also broadcast to "all" subscribers
        await ws_manager.broadcast_to_device("all", {
            "type": "telemetry",
            "device_id": device_id,
            "data": {
                "temp_c": temp_c,
                "recorded_at": recorded_at.isoformat(),
            },
        })

        # Check alert rules
        await self._check_alerts(db, device, temp_c, ws_manager)

    async def _check_alerts(
        self,
        db: AsyncSession,
        device: Device,
        temp_c: float,
        ws_manager,
    ):
        """Check if temperature triggers any alert rules."""
        result = await db.execute(
            select(AlertRule)
            .where(AlertRule.device_id == device.id)
            .where(AlertRule.is_active == True)
        )
        rules = result.scalars().all()

        for rule in rules:
            alert_type = None
            message = None

            if temp_c < rule.temp_min:
                alert_type = "low"
                message = f"Temperature {temp_c}°C is below minimum {rule.temp_min}°C"
            elif temp_c > rule.temp_max:
                alert_type = "high"
                message = f"Temperature {temp_c}°C is above maximum {rule.temp_max}°C"

            if alert_type:
                # Create alert
                alert = Alert(
                    device_id=device.id,
                    rule_id=rule.id,
                    temp_c=temp_c,
                    alert_type=alert_type,
                    message=message,
                )
                db.add(alert)
                await db.flush()

                logger.warning(f"Alert triggered for {device.device_id}: {message}")

                # Broadcast alert
                await ws_manager.broadcast_to_device(device.device_id, {
                    "type": "alert",
                    "device_id": device.device_id,
                    "data": {
                        "alert_type": alert_type,
                        "temp_c": temp_c,
                        "message": message,
                    },
                })
                await ws_manager.broadcast_to_device("all", {
                    "type": "alert",
                    "device_id": device.device_id,
                    "data": {
                        "alert_type": alert_type,
                        "temp_c": temp_c,
                        "message": message,
                    },
                })


# Global MQTT service instance
mqtt_service = MQTTService()


def get_mqtt_service() -> MQTTService:
    """Get the MQTT service instance."""
    return mqtt_service

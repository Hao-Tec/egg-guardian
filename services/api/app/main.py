"""FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import init_db
from app.routers import auth, devices, health, telemetry, users
from app.services.mqtt import get_mqtt_service

settings = get_settings()

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler for startup and shutdown."""
    # Startup
    logger.info("Starting Egg Guardian API...")
    await init_db()
    logger.info("Database initialized")

    # Start MQTT service
    mqtt_service = get_mqtt_service()
    await mqtt_service.start()

    yield

    # Shutdown
    logger.info("Shutting down Egg Guardian API...")
    await mqtt_service.stop()


app = FastAPI(
    title="Egg Guardian API",
    description="Real-time egg temperature monitoring system",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS middleware for Flutter web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router)
app.include_router(auth.router)
app.include_router(devices.router)
app.include_router(telemetry.router)
app.include_router(users.router)

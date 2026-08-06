"""FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import init_db
from app.routers import alerts, auth, devices, health, telemetry, users
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
    # Wait for DB to be reachable before trying to initialize it. This helps
    # when the managed database is cold-starting or was recently recreated.
    try:
        from app.database import wait_for_db

        await wait_for_db()
    except Exception as e:  # pragma: no cover - environment-specific
        logger.error(f"Database is not reachable: {e}")
        # Allow process to continue so Render can show healthy logs;
        # init_db will still fail later if DB is missing when called.

    try:
        await init_db()
        logger.info("Database initialized")
    except Exception as e:  # pragma: no cover - environment-specific
        logger.error(f"Failed to initialize database: {e}")

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
# In development mode, allow all origins for easier testing
# For production, set DEBUG=false and configure specific origins
if settings.debug or settings.cors_origins == "*":
    CORS_ORIGINS = ["*"]
else:
    CORS_ORIGINS = [
        origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=(
        True if not settings.debug else False
    ),  # Can't use credentials with *
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router)
app.include_router(auth.router)
app.include_router(devices.router)
app.include_router(telemetry.router)
app.include_router(users.router)
app.include_router(alerts.router)

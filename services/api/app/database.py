"""Database configuration and session management."""

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings

settings = get_settings()

db_url = settings.database_url
if db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql+asyncpg://", 1)
elif db_url.startswith("postgresql://"):
    db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)

engine = create_async_engine(
    db_url,
    echo=settings.debug,
    future=True,
)

async_session_maker = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Base class for all database models."""

    pass


async def get_db() -> AsyncSession:
    """Dependency for getting database sessions."""
    async with async_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


import asyncio
from sqlalchemy import text


async def wait_for_db(retries: int = 6, delay_seconds: int = 5) -> None:
    """Wait for the database to become available with exponential backoff.

    Raises the last exception if the DB is still unreachable after retries.
    """
    last_exc = None
    for attempt in range(1, retries + 1):
        try:
            async with engine.connect() as conn:
                # simple lightweight query to verify connectivity
                await conn.execute(text("SELECT 1"))
                return
        except Exception as exc:  # pragma: no cover - environment-specific
            last_exc = exc
            backoff = delay_seconds * attempt
            print(f"Database not available (attempt {attempt}/{retries}): {exc}")
            await asyncio.sleep(backoff)
    # All attempts failed
    raise last_exc


async def init_db() -> None:
    """Initialize database tables."""
    # Import models to register them with Base
    from app.models import User, Device, Telemetry, AlertRule, Alert  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

        # Add fcm_token column if it doesn't exist
        try:
            await conn.execute(
                text(
                    "ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(255)"
                )
            )
        except Exception:
            pass

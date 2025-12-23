"""Database configuration and session management."""

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings

settings = get_settings()

engine = create_async_engine(
    settings.database_url,
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


async def init_db() -> None:
    """Initialize database tables."""
    # Import models to register them with Base
    from app.models import User, Device, Telemetry, AlertRule, Alert  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Create default admin if no users exist
    await create_default_admin()


async def create_default_admin() -> None:
    """Create a default admin user if no users exist."""
    import logging
    from sqlalchemy import select
    from app.models import User
    from app.services.auth import get_password_hash

    logger = logging.getLogger(__name__)

    async with async_session_maker() as session:
        # Check if any users exist
        result = await session.execute(select(User).limit(1))
        if result.scalar_one_or_none() is not None:
            return  # Users already exist, skip

        # Create default admin
        admin = User(
            email="admin@eggguardian.local",
            hashed_password=get_password_hash("admin123"),
            full_name="Default Admin",
            is_active=True,
            is_superuser=True,
        )
        session.add(admin)
        await session.commit()
        logger.info("✅ Created default admin: admin@eggguardian.local / admin123")

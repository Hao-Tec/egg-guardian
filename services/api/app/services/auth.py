"""Authentication service with JWT tokens."""

from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models import User

settings = get_settings()

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)


def create_access_token(user: User) -> str:
    """Create a JWT access token."""
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    pwd_claim = user.hashed_password[-10:] if user.hashed_password else "none"
    to_encode = {"sub": str(user.id), "exp": expire, "type": "access", "pwd": pwd_claim}
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_refresh_token(user: User) -> str:
    """Create a JWT refresh token."""
    expire = datetime.now(timezone.utc) + timedelta(
        days=settings.refresh_token_expire_days
    )
    pwd_claim = user.hashed_password[-10:] if user.hashed_password else "none"
    to_encode = {"sub": str(user.id), "exp": expire, "type": "refresh", "pwd": pwd_claim}
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def verify_token(token: str, token_type: str = "access") -> Optional[dict]:
    """Verify a JWT token and return its payload."""
    try:
        payload = jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        if payload.get("type") != token_type:
            return None
        return payload
    except (JWTError, ValueError):
        return None


def create_reset_token(user_id: int) -> str:
    """Create a short-lived (15 min) JWT for password reset."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode = {"sub": str(user_id), "exp": expire, "type": "reset"}
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


async def update_user_password(db: AsyncSession, user: User, new_password: str) -> None:
    """Hash and persist a new password for the given user."""
    user.hashed_password = get_password_hash(new_password)
    await db.flush()
    await db.refresh(user)


async def get_user_by_email(db: AsyncSession, email: str) -> Optional[User]:
    """Get user by email."""
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def get_user_by_id(db: AsyncSession, user_id: int) -> Optional[User]:
    """Get user by ID."""
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def create_user(
    db: AsyncSession, email: str, password: str, full_name: Optional[str] = None,
    job_role: Optional[str] = None, is_superuser: bool = False, is_active: bool = False
) -> User:
    """Create a new user."""
    hashed_password = get_password_hash(password)
    user = User(
        email=email,
        hashed_password=hashed_password,
        full_name=full_name,
        job_role=job_role,
        is_superuser=is_superuser,
        is_active=is_active,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user


async def get_all_admins(db: AsyncSession) -> list[User]:
    """Fetch all superuser admins from the database."""
    result = await db.execute(select(User).where(User.is_superuser == True))
    return result.scalars().all()


async def authenticate_user(
    db: AsyncSession, email: str, password: str
) -> Optional[User]:
    """Authenticate a user by email and password."""
    user = await get_user_by_email(db, email)
    if not user:
        return None
    if not verify_password(password, user.hashed_password):
        return None
    return user

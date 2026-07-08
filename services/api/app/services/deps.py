"""Authentication dependencies for FastAPI."""

from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User
from app.services.auth import get_user_by_id, verify_token

security = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Get current authenticated user from JWT token."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = verify_token(credentials.credentials, "access")
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = int(payload.get("sub"))
    user = await get_user_by_id(db, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user",
        )

    # Validate that password hasn't changed since token was issued
    pwd_claim = payload.get("pwd")
    current_pwd_suffix = user.hashed_password[-10:] if user.hashed_password else "none"
    if pwd_claim and pwd_claim != current_pwd_suffix:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired due to password change. Please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    """Get current user if authenticated, None otherwise."""
    if credentials is None:
        return None

    payload = verify_token(credentials.credentials, "access")
    if payload is None:
        return None

    user_id = int(payload.get("sub"))
    user = await get_user_by_id(db, user_id)
    if not user:
        return None

    # Validate that password hasn't changed since token was issued
    pwd_claim = payload.get("pwd")
    current_pwd_suffix = user.hashed_password[-10:] if user.hashed_password else "none"
    if pwd_claim and pwd_claim != current_pwd_suffix:
        return None

    return user


async def get_current_superuser(
    current_user: User = Depends(get_current_user),
) -> User:
    """Get current user and verify they are a superuser (admin)."""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )
    return current_user

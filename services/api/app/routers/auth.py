"""Authentication router with login, register, and token refresh."""

import asyncio
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User
from app.schemas import (
    AdminPasswordResetRequest,
    ForgotPasswordRequest,
    FCMTokenRequest,
    RefreshTokenRequest,
    ResetPasswordRequest,
    Token,
    UserCreate,
    UserLogin,
    UserResponse,
)
from app.services.auth import (
    authenticate_user,
    create_access_token,
    create_refresh_token,
    create_reset_token,
    create_user,
    get_all_admins,
    get_user_by_email,
    get_user_by_id,
    update_user_password,
    verify_token,
)
from app.services.deps import get_current_user
from app.services.email import send_new_registration_email, send_password_reset_email

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db),
):
    """Register a new user account. The very first user is auto-approved as Superadmin.
    All subsequent users are set to Pending (is_active=False) until approved by an admin."""
    existing = await get_user_by_email(db, user_data.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    from sqlalchemy import select
    result = await db.execute(select(User).limit(1))
    is_first_user = result.scalar_one_or_none() is None

    user = await create_user(
        db,
        email=user_data.email,
        password=user_data.password,
        full_name=user_data.full_name,
        job_role=user_data.job_role,
        is_superuser=is_first_user,
        is_active=is_first_user,  # First user active immediately; others need approval
    )

    # If not the first user, notify all admins by email
    if not is_first_user:
        admins = await get_all_admins(db)
        admin_emails = [a.email for a in admins]
        # Fire-and-forget: run email sending in background
        asyncio.create_task(
            send_new_registration_email(
                admin_emails=admin_emails,
                new_user_email=user.email,
                new_user_name=user.full_name or user.email,
                new_user_role=user.job_role or "Not specified",
            )
        )

    return user


@router.post("/login", response_model=Token)
async def login(
    credentials: UserLogin,
    db: AsyncSession = Depends(get_db),
):
    """Login and receive JWT tokens."""
    user = await authenticate_user(db, credentials.email, credentials.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    # Block pending users from logging in
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account is pending admin approval. Please wait for an administrator to approve your registration.",
        )

    return Token(
        access_token=create_access_token(user),
        refresh_token=create_refresh_token(user),
    )


@router.post("/refresh", response_model=Token)
async def refresh_token(
    request: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """Refresh access token using refresh token."""
    payload = verify_token(request.refresh_token, "refresh")
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )
    user_id = int(payload.get("sub"))

    user = await get_user_by_id(db, user_id)
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )

    # Validate that password hasn't changed since token was issued
    pwd_claim = payload.get("pwd")
    current_pwd_suffix = user.hashed_password[-10:] if user.hashed_password else "none"
    if pwd_claim and pwd_claim != current_pwd_suffix:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired due to password change. Please log in again.",
        )

    return Token(
        access_token=create_access_token(user),
        refresh_token=create_refresh_token(user),
    )


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: User = Depends(get_current_user),
):
    """Get current authenticated user's information."""
    return current_user


@router.post("/forgot-password", status_code=status.HTTP_200_OK)
async def forgot_password(
    request: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """Request a password reset. Always returns 200 to avoid leaking whether an email exists."""
    user = await get_user_by_email(db, request.email)
    if user and user.is_active:
        token = create_reset_token(user.id)
        asyncio.create_task(
            send_password_reset_email(
                user_email=user.email,
                user_name=user.full_name or user.email,
                reset_token=token,
            )
        )
    return {"message": "If that email is registered, a reset token has been sent."}


@router.post("/reset-password", status_code=status.HTTP_200_OK)
async def reset_password(
    request: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """Reset password using the token received via email."""
    payload = verify_token(request.token, "reset")
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token.",
        )
    user_id = int(payload.get("sub"))
    user = await get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    await update_user_password(db, user, request.new_password)
    return {"message": "Password has been reset successfully. You can now log in."}


@router.post("/fcm-token", status_code=status.HTTP_200_OK)
async def update_fcm_token(
    request: FCMTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Register or update the FCM token for the current user."""
    current_user.fcm_token = request.token
    await db.commit()
    return {"message": "FCM token updated successfully."}

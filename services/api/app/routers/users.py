"""User management router for admin."""

import asyncio
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User
from app.schemas import AdminPasswordResetRequest, UserResponse
from app.services.auth import update_user_password
from app.services.deps import get_current_superuser
from app.services.email import send_account_approved_email


router = APIRouter(prefix="/api/v1/users", tags=["Users"])


@router.get("", response_model=list[UserResponse])
async def list_users(
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_superuser),
):
    """List all registered users (admin only)."""
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    users = result.scalars().all()
    return users


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_superuser),
):
    """Get a specific user by ID."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return user


@router.patch("/{user_id}/approve", response_model=UserResponse)
async def approve_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_superuser),
):
    """Approve a pending user account, granting them access (admin only)."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    if user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already active.",
        )

    user.is_active = True
    await db.flush()
    await db.refresh(user)

    # Notify the user their account was approved
    asyncio.create_task(
        send_account_approved_email(
            user_email=user.email,
            user_name=user.full_name or user.email,
        )
    )

    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_superuser),
):
    """Delete a user (admin only). Cannot delete the last admin or self."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Prevent self-deletion
    if user.id == admin_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot delete your own account.",
        )

    # Protect root owner
    if user.id == 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The root owner account cannot be deleted.",
        )

    # Protect last admin
    if user.is_superuser:
        admin_count = await db.execute(select(User).where(User.is_superuser == True))
        if len(admin_count.scalars().all()) <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot delete the last admin. Promote another user first.",
            )

    await db.delete(user)


@router.patch("/{user_id}/toggle-admin", response_model=UserResponse)
async def toggle_admin_status(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_superuser),
):
    """Toggle admin (superuser) status for a user (admin only). Cannot demote the last admin or self."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Prevent self-demotion
    if user.id == admin_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot change your own admin status.",
        )

    # Protect root owner
    if user.id == 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The root owner's admin status cannot be revoked.",
        )

    # Protect last admin from being demoted
    if user.is_superuser:
        admin_count = await db.execute(select(User).where(User.is_superuser == True))
        if len(admin_count.scalars().all()) <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot demote the last admin. Promote another user first.",
            )

    # Toggle is_superuser
    user.is_superuser = not user.is_superuser
    await db.flush()
    await db.refresh(user)
    return user


@router.patch("/{user_id}/password", response_model=UserResponse)
async def admin_reset_password(
    user_id: int,
    body: AdminPasswordResetRequest,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_superuser),
):
    """Admin force-reset a user's password (admin only)."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
        
    # Prevent resetting root owner password unless it's the root owner themselves
    if user.id == 1 and admin_user.id != 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the root owner can reset their own password via admin panel.",
        )
        
    await update_user_password(db, user, body.new_password)
    return user

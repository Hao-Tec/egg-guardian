"""Pydantic schemas for API request/response validation."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


# ============== Auth Schemas ==============


class Token(BaseModel):
    """JWT token response."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenPayload(BaseModel):
    """JWT token payload."""

    sub: int
    exp: datetime


class RefreshTokenRequest(BaseModel):
    """Refresh token request."""

    refresh_token: str


# ============== User Schemas ==============


class UserCreate(BaseModel):
    """User registration schema."""

    email: EmailStr
    password: str = Field(..., min_length=6)
    full_name: Optional[str] = None


class UserLogin(BaseModel):
    """User login schema."""

    email: EmailStr
    password: str


class UserResponse(BaseModel):
    """User response schema."""

    id: int
    email: str
    full_name: Optional[str]
    is_active: bool
    is_superuser: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ============== Device Schemas ==============


class DeviceCreate(BaseModel):
    """Device registration schema."""

    device_id: str = Field(..., min_length=1, max_length=50)
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None


class DeviceUpdate(BaseModel):
    """Device update schema."""

    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = None
    is_active: Optional[bool] = None


class DeviceResponse(BaseModel):
    """Device response schema."""

    id: int
    device_id: str
    name: str
    description: Optional[str]
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============== Telemetry Schemas ==============


class TelemetryCreate(BaseModel):
    """Telemetry ingestion schema (from MQTT)."""

    device_id: str
    ts: datetime
    temp_c: float = Field(..., ge=-50, le=100)


class TelemetryResponse(BaseModel):
    """Telemetry response schema."""

    id: int
    temp_c: float
    recorded_at: datetime
    received_at: datetime

    class Config:
        from_attributes = True


class TelemetryHistory(BaseModel):
    """Telemetry history response."""

    device_id: str
    device_name: str
    readings: list[TelemetryResponse]
    count: int


# ============== Alert Rule Schemas ==============


class AlertRuleCreate(BaseModel):
    """Alert rule creation schema."""

    temp_min: float = Field(default=35.0, ge=0, le=50)
    temp_max: float = Field(default=39.0, ge=0, le=50)


class AlertRuleResponse(BaseModel):
    """Alert rule response schema."""

    id: int
    device_id: int
    temp_min: float
    temp_max: float
    is_active: bool
    created_at: datetime
    device_name: Optional[str] = None

    class Config:
        from_attributes = True


# ============== Alert Schemas ==============


class AlertResponse(BaseModel):
    """Alert response schema."""

    id: int
    device_id: int
    rule_id: int
    temp_c: float
    alert_type: str
    message: str
    is_acknowledged: bool
    triggered_at: datetime
    acknowledged_at: Optional[datetime]

    class Config:
        from_attributes = True


# ============== WebSocket Schemas ==============


class WebSocketMessage(BaseModel):
    """WebSocket message format."""

    type: str  # "telemetry", "alert", "status"
    device_id: str
    data: dict
    timestamp: datetime = Field(default_factory=datetime.utcnow)

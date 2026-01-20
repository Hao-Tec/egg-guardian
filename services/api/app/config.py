"""Application configuration from environment variables."""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database
    database_url: str = Field(
        default="postgresql+asyncpg://egg_guardian:egg_guardian_secret@localhost:5432/egg_guardian",
        alias="DATABASE_URL"
    )

    # MQTT - explicit aliases for Docker compatibility
    mqtt_broker: str = Field(default="localhost", alias="MQTT_BROKER")
    mqtt_port: int = Field(default=1883, alias="MQTT_PORT")

    # JWT
    jwt_secret_key: str = Field(default="change-me-in-production", alias="JWT_SECRET_KEY")
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    access_token_expire_minutes: int = Field(default=30, alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    refresh_token_expire_days: int = Field(default=7, alias="REFRESH_TOKEN_EXPIRE_DAYS")

    # API
    api_host: str = Field(default="0.0.0.0", alias="API_HOST")
    api_port: int = Field(default=8000, alias="API_PORT")
    debug: bool = Field(default=False, alias="DEBUG")

    # FCM
    fcm_mock_mode: bool = Field(default=True, alias="FCM_MOCK_MODE")

    class Config:
        env_file = ".env"
        extra = "ignore"
        populate_by_name = True  # Allow both field name and alias


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


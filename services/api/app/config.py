"""Application configuration from environment variables."""

from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database
    database_url: str = "postgresql+asyncpg://egg_guardian:egg_guardian_secret@localhost:5432/egg_guardian"

    # MQTT
    mqtt_broker: str = "localhost"
    mqtt_port: int = 1883

    # JWT
    jwt_secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    # API
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    debug: bool = True

    # FCM
    fcm_mock_mode: bool = True

    class Config:
        env_file = ".env"
        extra = "ignore"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()

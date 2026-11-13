from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', extra='ignore')
    gemini_api_key: str = ''
    gemini_model: str = 'gemini-3.8-flash'
    app_api_key: str = ''
    allowed_origins: str = ''
    db_host: str = '127.0.0.1'
    db_port: int = 3306
    db_name: str = 'career_booster'
    db_user: str = ''
    db_password: str = ''
    jwt_secret: str = ''


@lru_cache
def settings() -> Settings:
    return Settings()

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    api_title: str = "国产化考试系统 API"
    api_version: str = "1.0.0"

    # DM8: store core exam metadata
    dm8_dsn: str = "dm+dmPython://SYSDBA:Dameng123@127.0.0.1:5236"
    # MySQL: optional read replica / analytics
    mysql_dsn: str = "mysql+pymysql://root:root@127.0.0.1:3306/exam_system"

    # symmetric key for result payload encryption
    upload_shared_key: str = "change-this-32-byte-key"
    jwt_secret: str = "change-this-jwt-secret"
    jwt_expire_minutes: int = 480

    cors_origins: str = "http://localhost:5173,http://127.0.0.1:5173"

    model_config = SettingsConfigDict(env_prefix="EXAM_", env_file=".env", extra="ignore")

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


settings = Settings()

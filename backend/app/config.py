from pydantic import BaseSettings


class Settings(BaseSettings):
    oracle_user: str
    oracle_password: str
    oracle_dsn: str

    class Config:
        env_file = "../.env"  # backend/.env
        env_file_encoding = "utf-8"


settings = Settings()
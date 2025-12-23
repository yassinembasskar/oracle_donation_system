import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    ORACLE_USER: str = os.getenv("ORACLE_USER")
    ORACLE_PASSWORD: str = os.getenv("ORACLE_PASSWORD")
    ORACLE_HOST: str = os.getenv("ORACLE_HOST")
    ORACLE_PORT: str = os.getenv("ORACLE_PORT")
    ORACLE_SERVICE: str = os.getenv("ORACLE_SERVICE")
    SQLALCHEMY_DATABASE_URL: str = (
        f"oracle+oracledb://{ORACLE_USER}:{ORACLE_PASSWORD}@{ORACLE_HOST}:{ORACLE_PORT}/?service_name={ORACLE_SERVICE}"
        if ORACLE_USER and ORACLE_PASSWORD and ORACLE_HOST and ORACLE_PORT and ORACLE_SERVICE else None
    )

settings = Settings()


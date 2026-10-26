from pathlib import Path
from typing import Literal
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    SUPABASE_URL: str = ""
    SUPABASE_KEY: str = Field(default="", alias="SUPABASE_SECRET_KEY")
    SUPABASE_JWKS_URL: str = ""
    GEMINI_API_KEY: str = ""
    AI_PROVIDER: Literal["gemini", "ollama"] = "ollama"
    GENERATION_MODEL: str = "gemini-2.5-flash"
    EMBEDDING_MODEL: str = "gemini-embedding-2"
    OLLAMA_URL: str = "http://127.0.0.1:11434"
    OLLAMA_MODEL: str = "gemma3:4b"
    OLLAMA_EMBEDDING_MODEL: str = "nomic-embed-text"
    MODEL_TIMEOUT_SECONDS: int = Field(default=120, ge=1, le=300)
    DATA_DIR: Path = Path(".local")
    CHECKPOINT_DATABASE_URL: str = ""
    STORAGE_BUCKET: str = "journal-assets"
    MAX_UPLOAD_BYTES: int = Field(default=10485760, ge=1024, le=26214400)
    WHISPER_MODEL: str = "base"
    ENABLE_AUDIO: bool = False
    ENABLE_DOCLING: bool = False
    GOOGLE_CALENDAR_CLIENT_ID: str = ""
    GOOGLE_CALENDAR_CLIENT_SECRET: str = ""
    GOOGLE_CALENDAR_REDIRECT_URL: str = "http://127.0.0.1:8000/v1/calendar/callback"
    TOKEN_ENCRYPTION_KEY: str = ""
    CORS_ORIGINS: list[str] = ["http://localhost:8080", "http://127.0.0.1:8080"]
    WORKER_POLL_SECONDS: float = Field(default=2, ge=0.1)
    WORKER_LEASE_SECONDS: int = Field(default=900, ge=300)
    MAX_RUN_ATTEMPTS: int = Field(default=3, ge=1, le=5)
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore", populate_by_name=True)

settings = Settings()

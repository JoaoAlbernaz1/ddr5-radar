"""Fonte unica de configuracao. Ninguem le os.environ fora daqui."""
import os
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class Config:
    database_url: str
    telegram_token: str | None
    telegram_chat_id: str | None
    ml_client_id: str | None
    ml_client_secret: str | None


def carregar_config() -> Config:
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError(
            "DATABASE_URL nao esta definida. No GitHub Actions ela vem dos "
            "Secrets; localmente, exporte antes de rodar."
        )
    return Config(
        database_url=database_url,
        telegram_token=os.environ.get("TELEGRAM_TOKEN"),
        telegram_chat_id=os.environ.get("TELEGRAM_CHAT_ID"),
        ml_client_id=os.environ.get("ML_CLIENT_ID"),
        ml_client_secret=os.environ.get("ML_CLIENT_SECRET"),
    )

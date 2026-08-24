import pytest

from ddr5_radar.config import carregar_config


def test_carrega_database_url_do_ambiente(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@host/db")
    config = carregar_config()
    assert config.database_url == "postgresql+psycopg://u:p@host/db"


def test_campos_opcionais_ficam_none_quando_ausentes(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@host/db")
    monkeypatch.delenv("TELEGRAM_TOKEN", raising=False)
    config = carregar_config()
    assert config.telegram_token is None


def test_explode_quando_falta_database_url(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        carregar_config()

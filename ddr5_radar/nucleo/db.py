from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from ddr5_radar.config import carregar_config


def criar_sessao() -> sessionmaker[Session]:
    config = carregar_config()
    engine = create_engine(config.database_url, pool_pre_ping=True)
    return sessionmaker(engine, expire_on_commit=False)

"""Schema completo, incluindo as tabelas que so o Plano 2 usa.

Dinheiro e sempre inteiro em centavos. Datas sempre com fuso.
"""
from datetime import datetime

from sqlalchemy import (
    Boolean, DateTime, Float, ForeignKey, Index, Integer, String, Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

from ddr5_radar.contrato import Condicao, Formato


class Base(DeclarativeBase):
    pass


class Oferta(Base):
    """Um anuncio numa loja. Vive enquanto a loja o mantiver no ar."""

    __tablename__ = "ofertas"
    __table_args__ = (
        UniqueConstraint("loja", "id_na_loja", name="uq_oferta_loja_id"),
        Index("ix_oferta_part_number", "part_number"),
        Index("ix_oferta_chave", "chave_canonica"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    loja: Mapped[str] = mapped_column(String(32))
    id_na_loja: Mapped[str] = mapped_column(String(64))
    titulo: Mapped[str] = mapped_column(Text)
    url: Mapped[str] = mapped_column(Text)
    url_imagem: Mapped[str | None] = mapped_column(Text, default=None)

    # identidade do produto (spec §7)
    part_number: Mapped[str | None] = mapped_column(String(64), default=None)
    chave_canonica: Mapped[str | None] = mapped_column(String(128), default=None)
    marca: Mapped[str | None] = mapped_column(String(32), default=None)
    linha: Mapped[str | None] = mapped_column(String(32), default=None)
    capacidade_gb: Mapped[int | None] = mapped_column(Integer, default=None)
    modulos: Mapped[int | None] = mapped_column(Integer, default=None)
    velocidade_mts: Mapped[int | None] = mapped_column(Integer, default=None)
    latencia_cl: Mapped[int | None] = mapped_column(Integer, default=None)
    # str e nao Mapped[Formato]: a coluna e String, e o SQLAlchemy devolve str
    # na leitura. Declarar o enum aqui seria mentir sobre o tipo que volta.
    formato: Mapped[str] = mapped_column(String(16), default=Formato.DIMM.value)
    rgb: Mapped[bool] = mapped_column(Boolean, default=False)

    condicao: Mapped[str] = mapped_column(String(16), default=Condicao.DESCONHECIDO.value)
    vendedor: Mapped[str | None] = mapped_column(String(128), default=None)
    reputacao_vendedor: Mapped[float | None] = mapped_column(Float, default=None)

    primeira_vez_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ultima_vez_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    precos: Mapped[list["PrecoObservado"]] = relationship(
        back_populates="oferta", order_by="PrecoObservado.observado_em"
    )


class PrecoObservado(Base):
    """So grava quando o preco muda -- 144 coletas por dia sem isso viram lixo."""

    __tablename__ = "precos"
    __table_args__ = (Index("ix_preco_oferta_data", "oferta_id", "observado_em"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    oferta_id: Mapped[int] = mapped_column(ForeignKey("ofertas.id"))
    rodada_id: Mapped[int] = mapped_column(ForeignKey("rodadas.id"))
    preco_centavos: Mapped[int] = mapped_column(Integer)
    preco_original_centavos: Mapped[int | None] = mapped_column(Integer, default=None)
    em_estoque: Mapped[bool] = mapped_column(Boolean, default=True)
    centavos_por_gb: Mapped[int | None] = mapped_column(Integer, default=None)
    observado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    oferta: Mapped[Oferta] = relationship(back_populates="precos")


class Rodada(Base):
    __tablename__ = "rodadas"

    id: Mapped[int] = mapped_column(primary_key=True)
    iniciada_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    terminada_em: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), default=None
    )
    ofertas_vistas: Mapped[int] = mapped_column(Integer, default=0)
    precos_gravados: Mapped[int] = mapped_column(Integer, default=0)


class SaudeAdaptador(Base):
    """Quem quebrou, quando e por que. E o que vira 'Pichau: sem dados ha 3h'."""

    __tablename__ = "saude_adaptadores"

    id: Mapped[int] = mapped_column(primary_key=True)
    rodada_id: Mapped[int] = mapped_column(ForeignKey("rodadas.id"))
    loja: Mapped[str] = mapped_column(String(32))
    sucesso: Mapped[bool] = mapped_column(Boolean)
    qtd_ofertas: Mapped[int] = mapped_column(Integer, default=0)
    erro: Mapped[str | None] = mapped_column(Text, default=None)
    duracao_ms: Mapped[int] = mapped_column(Integer, default=0)


class Alerta(Base):
    """Usada so no Plano 2. Existe agora para nao migrar tabela com dado dentro."""

    __tablename__ = "alertas"

    id: Mapped[int] = mapped_column(primary_key=True)
    oferta_id: Mapped[int] = mapped_column(ForeignKey("ofertas.id"))
    selo: Mapped[str] = mapped_column(String(8))    # "bug" | "promo"
    sinal: Mapped[str] = mapped_column(String(24))  # desvio_lojas | queda_historico | curva_mercado
    preco_centavos: Mapped[int] = mapped_column(Integer)
    referencia_centavos: Mapped[int | None] = mapped_column(Integer, default=None)
    desvio_percentual: Mapped[float | None] = mapped_column(Float, default=None)
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    notificado_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    dispensado_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)


class Configuracao(Base):
    """Linha unica. Usada so no Plano 2; valores iniciais vem da spec §8."""

    __tablename__ = "configuracao"

    id: Mapped[int] = mapped_column(primary_key=True, default=1)
    limiar_bug_mediana: Mapped[float] = mapped_column(Float, default=0.55)
    limiar_promo_mediana: Mapped[float] = mapped_column(Float, default=0.80)
    limiar_bug_queda: Mapped[float] = mapped_column(Float, default=0.40)
    limiar_promo_queda: Mapped[float] = mapped_column(Float, default=0.20)
    percentil_curva: Mapped[int] = mapped_column(Integer, default=5)
    min_lojas_mediana: Mapped[int] = mapped_column(Integer, default=3)
    silencio_inicio_hora: Mapped[int] = mapped_column(Integer, default=23)
    silencio_fim_hora: Mapped[int] = mapped_column(Integer, default=7)
    lojas_desligadas: Mapped[str] = mapped_column(Text, default="")

from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from ddr5_radar.cli import executar_coleta
from ddr5_radar.contrato import Condicao, OfertaCrua
from ddr5_radar.nucleo.modelos import Base, Oferta, SaudeAdaptador


class AdaptadorFalso:
    loja = "falsa"

    async def buscar(self, termo):
        return [
            OfertaCrua(
                loja="falsa", id_na_loja="1",
                titulo="Memória Kingston Fury Beast, 16GB, 5600MHz, DDR5, CL40 - KF556C40BB-16",
                preco_centavos=189999, preco_original_centavos=None, em_estoque=True,
                url="https://x", url_imagem=None, condicao=Condicao.NOVO,
                vendedor=None, reputacao_vendedor=None, coletado_em=datetime.now(UTC),
            )
        ]


class AdaptadorCaido:
    loja = "caida"
    async def buscar(self, termo): raise RuntimeError("caiu")


@pytest.fixture
def sessao_falsa(monkeypatch):
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    fabrica = sessionmaker(engine, expire_on_commit=False)
    monkeypatch.setattr("ddr5_radar.cli.criar_sessao", lambda: fabrica)
    return fabrica


async def test_coleta_ponta_a_ponta_grava_no_banco(sessao_falsa, monkeypatch):
    monkeypatch.setattr("ddr5_radar.cli.ADAPTADORES", {"falsa": AdaptadorFalso()})
    resumo = await executar_coleta("ddr5")

    with sessao_falsa() as s:
        oferta = s.scalars(select(Oferta)).one()
        assert oferta.part_number == "KF556C40BB-16"
    assert "1 nova" in resumo


async def test_loja_caida_e_registrada_e_a_rodada_termina(sessao_falsa, monkeypatch):
    monkeypatch.setattr(
        "ddr5_radar.cli.ADAPTADORES",
        {"falsa": AdaptadorFalso(), "caida": AdaptadorCaido()},
    )
    resumo = await executar_coleta("ddr5")

    with sessao_falsa() as s:
        saude = {x.loja: x for x in s.scalars(select(SaudeAdaptador)).all()}
    assert saude["caida"].sucesso is False
    assert saude["falsa"].sucesso is True
    assert "caida" in resumo


async def test_filtro_de_lojas_respeitado(sessao_falsa, monkeypatch):
    monkeypatch.setattr(
        "ddr5_radar.cli.ADAPTADORES",
        {"falsa": AdaptadorFalso(), "caida": AdaptadorCaido()},
    )
    await executar_coleta("ddr5", lojas=["falsa"])

    with sessao_falsa() as s:
        assert {x.loja for x in s.scalars(select(SaudeAdaptador)).all()} == {"falsa"}

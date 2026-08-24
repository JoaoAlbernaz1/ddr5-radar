from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from ddr5_radar.contrato import Condicao, OfertaCrua
from ddr5_radar.nucleo.modelos import Base, Oferta, PrecoObservado
from ddr5_radar.persistencia import (
    finalizar_rodada, gravar_ofertas, iniciar_rodada, registrar_saude,
)


@pytest.fixture
def sessao():
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        yield s


def _crua(preco_centavos: int = 189999, **extra) -> OfertaCrua:
    campos = dict(
        loja="kabum",
        id_na_loja="708332",
        titulo="Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5, CL36 - KF556C36BBE-16",
        preco_centavos=preco_centavos,
        preco_original_centavos=223528,
        em_estoque=True,
        url="https://www.kabum.com.br/produto/708332/x",
        url_imagem=None,
        condicao=Condicao.NOVO,
        vendedor="KaBuM!",
        reputacao_vendedor=None,
        coletado_em=datetime.now(UTC),
    )
    campos.update(extra)
    return OfertaCrua(**campos)


def test_grava_oferta_nova_com_atributos_extraidos(sessao):
    rodada = iniciar_rodada(sessao)
    resumo = gravar_ofertas(sessao, rodada, [_crua()])
    assert resumo.ofertas_novas == 1
    assert resumo.precos_gravados == 1

    oferta = sessao.scalars(select(Oferta)).one()
    assert oferta.part_number == "KF556C36BBE-16"
    assert oferta.capacidade_gb == 16
    assert oferta.velocidade_mts == 5600


def test_calcula_centavos_por_gb(sessao):
    rodada = iniciar_rodada(sessao)
    gravar_ofertas(sessao, rodada, [_crua(preco_centavos=189999)])
    preco = sessao.scalars(select(PrecoObservado)).one()
    assert preco.centavos_por_gb == 189999 // 16


def test_preco_repetido_nao_vira_linha_nova(sessao):
    rodada = iniciar_rodada(sessao)
    gravar_ofertas(sessao, rodada, [_crua(preco_centavos=189999)])
    segunda = iniciar_rodada(sessao)
    resumo = gravar_ofertas(sessao, segunda, [_crua(preco_centavos=189999)])

    assert resumo.ofertas_novas == 0
    assert resumo.ofertas_atualizadas == 1
    assert resumo.precos_gravados == 0
    assert len(sessao.scalars(select(PrecoObservado)).all()) == 1


def test_preco_diferente_vira_linha_nova(sessao):
    rodada = iniciar_rodada(sessao)
    gravar_ofertas(sessao, rodada, [_crua(preco_centavos=189999)])
    segunda = iniciar_rodada(sessao)
    resumo = gravar_ofertas(sessao, segunda, [_crua(preco_centavos=99999)])

    assert resumo.precos_gravados == 1
    assert len(sessao.scalars(select(PrecoObservado)).all()) == 2


def test_pc_gamer_com_ddr5_e_descartado(sessao):
    rodada = iniciar_rodada(sessao)
    pc = _crua(titulo="PC Gamer Plataforma AMD Ryzen 7000 DDR5 AM5 32GB (FULL CUSTOM)")
    resumo = gravar_ofertas(sessao, rodada, [pc])

    assert resumo.descartadas == 1
    assert sessao.scalars(select(Oferta)).all() == []


def test_ddr4_e_descartada_na_entrada(sessao):
    rodada = iniciar_rodada(sessao)
    ddr4 = _crua(titulo="Memória Kingston Fury Beast, 16GB, 3200MHz, DDR4, CL16")
    resumo = gravar_ofertas(sessao, rodada, [ddr4])

    assert resumo.descartadas == 1
    assert resumo.ofertas_novas == 0
    assert sessao.scalars(select(Oferta)).all() == []


def test_saida_de_estoque_vira_linha_nova(sessao):
    rodada = iniciar_rodada(sessao)
    gravar_ofertas(sessao, rodada, [_crua(em_estoque=True)])
    segunda = iniciar_rodada(sessao)
    resumo = gravar_ofertas(sessao, segunda, [_crua(em_estoque=False)])
    assert resumo.precos_gravados == 1


def test_registra_saude_e_fecha_rodada(sessao):
    rodada = iniciar_rodada(sessao)
    registrar_saude(sessao, rodada, "pichau", sucesso=False, qtd=0,
                    erro="403 anti-bot", duracao_ms=1200)
    resumo = gravar_ofertas(sessao, rodada, [_crua()])
    finalizar_rodada(sessao, rodada, resumo)

    assert rodada.terminada_em is not None
    assert rodada.precos_gravados == 1

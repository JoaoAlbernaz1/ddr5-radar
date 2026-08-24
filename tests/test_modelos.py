from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ddr5_radar.contrato import Condicao, Formato
from ddr5_radar.nucleo.modelos import Base, Oferta, PrecoObservado, Rodada


@pytest.fixture
def sessao():
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        yield s


def _oferta(**extra) -> Oferta:
    campos = dict(
        loja="kabum",
        id_na_loja="708332",
        titulo="Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5",
        url="https://www.kabum.com.br/produto/708332/x",
        part_number="KF556C36BBE-16",
        chave_canonica="kingston|fury-beast|16|?|5600|dimm|sem-rgb",
        marca="kingston",
        capacidade_gb=16,
        velocidade_mts=5600,
        formato=Formato.DIMM.value,
        condicao=Condicao.NOVO.value,
        primeira_vez_em=datetime.now(UTC),
        ultima_vez_em=datetime.now(UTC),
    )
    campos.update(extra)
    return Oferta(**campos)


def test_a_mesma_oferta_nao_entra_duas_vezes(sessao):
    sessao.add(_oferta())
    sessao.commit()
    sessao.add(_oferta())
    with pytest.raises(IntegrityError):
        sessao.commit()


def test_mesmo_id_em_lojas_diferentes_convive(sessao):
    sessao.add(_oferta(loja="kabum"))
    sessao.add(_oferta(loja="pichau"))
    sessao.commit()
    assert len(sessao.scalars(select(Oferta)).all()) == 2


def test_preco_pertence_a_uma_oferta(sessao):
    oferta = _oferta()
    rodada = Rodada(iniciada_em=datetime.now(UTC))
    sessao.add_all([oferta, rodada])
    sessao.flush()
    sessao.add(
        PrecoObservado(
            oferta_id=oferta.id,
            rodada_id=rodada.id,
            preco_centavos=189999,
            em_estoque=True,
            centavos_por_gb=11874,
            observado_em=datetime.now(UTC),
        )
    )
    sessao.commit()
    assert oferta.precos[0].preco_centavos == 189999

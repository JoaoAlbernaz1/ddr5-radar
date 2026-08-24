from datetime import UTC, datetime

import pytest

from ddr5_radar.contrato import (
    Condicao,
    OfertaCrua,
    reais_para_centavos,
)


def test_oferta_e_imutavel():
    oferta = OfertaCrua(
        loja="kabum",
        id_na_loja="708332",
        titulo="Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5",
        preco_centavos=189999,
        preco_original_centavos=223528,
        em_estoque=True,
        url="https://www.kabum.com.br/produto/708332/x",
        url_imagem=None,
        condicao=Condicao.NOVO,
        vendedor="KaBuM!",
        reputacao_vendedor=None,
        coletado_em=datetime.now(UTC),
    )
    with pytest.raises(AttributeError):
        oferta.preco_centavos = 1


@pytest.mark.parametrize(
    ("entrada", "esperado"),
    [
        (1899.99, 189999),
        (1175.02, 117502),
        (5239.9, 523990),
        ("1.899,99", 189999),
        ("R$ 1.899,99", 189999),
        ("963,99", 96399),
        (0, 0),
    ],
)
def test_converte_reais_para_centavos(entrada, esperado):
    assert reais_para_centavos(entrada) == esperado

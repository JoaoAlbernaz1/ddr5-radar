from datetime import UTC, datetime

import httpx
import pytest
import respx

from ddr5_radar.coleta.adaptadores.mercadolivre import (
    AdaptadorMercadoLivre, converter_resultado,
)
from ddr5_radar.contrato import (
    AdaptadorNaoConfigurado, ColetaBloqueada, Condicao,
)

ITEM = {
    "id": "MLB3612345678",
    "title": "KIT MEMORIA RAM DDR5 32GB 6000 KINGSTON FURY BEAST RGB",
    "price": 4199.9,
    "original_price": 4899.9,
    "available_quantity": 5,
    "permalink": "https://produto.mercadolivre.com.br/MLB-3612345678-x",
    "thumbnail": "https://http2.mlstatic.com/x.jpg",
    "condition": "new",
    "seller": {"id": 123, "nickname": "LOJA_HARDWARE"},
}


def test_converte_item_da_api():
    oferta = converter_resultado(ITEM, datetime.now(UTC))
    assert oferta.loja == "mercadolivre"
    assert oferta.id_na_loja == "MLB3612345678"
    assert oferta.preco_centavos == 419990
    assert oferta.preco_original_centavos == 489990
    assert oferta.em_estoque is True
    assert oferta.condicao is Condicao.NOVO
    assert oferta.vendedor == "LOJA_HARDWARE"


def test_sem_estoque_quando_quantidade_zero():
    item = ITEM | {"available_quantity": 0}
    assert converter_resultado(item, datetime.now(UTC)).em_estoque is False


def test_usado_e_marcado_como_usado():
    item = ITEM | {"condition": "used"}
    assert converter_resultado(item, datetime.now(UTC)).condicao is Condicao.USADO


def test_sem_preco_original_fica_none():
    item = {k: v for k, v in ITEM.items() if k != "original_price"}
    assert converter_resultado(item, datetime.now(UTC)).preco_original_centavos is None


async def test_sem_credencial_avisa_que_falta_configuracao(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@h/d")
    monkeypatch.delenv("ML_CLIENT_ID", raising=False)
    monkeypatch.delenv("ML_CLIENT_SECRET", raising=False)
    with pytest.raises(AdaptadorNaoConfigurado, match="ML_CLIENT_ID"):
        await AdaptadorMercadoLivre().buscar("ddr5")


@respx.mock
async def test_busca_usa_o_token_obtido(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@h/d")
    monkeypatch.setenv("ML_CLIENT_ID", "id")
    monkeypatch.setenv("ML_CLIENT_SECRET", "segredo")

    respx.post("https://api.mercadolibre.com/oauth/token").mock(
        return_value=httpx.Response(200, json={"access_token": "T0KEN"})
    )
    rota = respx.get("https://api.mercadolibre.com/sites/MLB/search").mock(
        side_effect=[
            httpx.Response(200, json={"results": [ITEM]}),
            httpx.Response(200, json={"results": []}),
        ]
    )

    ofertas = await AdaptadorMercadoLivre().buscar("ddr5")

    assert len(ofertas) == 1
    assert rota.calls[0].request.headers["Authorization"] == "Bearer T0KEN"


@respx.mock
async def test_403_na_busca_vira_bloqueio(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@h/d")
    monkeypatch.setenv("ML_CLIENT_ID", "id")
    monkeypatch.setenv("ML_CLIENT_SECRET", "segredo")

    respx.post("https://api.mercadolibre.com/oauth/token").mock(
        return_value=httpx.Response(200, json={"access_token": "T0KEN"})
    )
    respx.get("https://api.mercadolibre.com/sites/MLB/search").mock(
        return_value=httpx.Response(403, json={"message": "forbidden"})
    )

    with pytest.raises(ColetaBloqueada):
        await AdaptadorMercadoLivre().buscar("ddr5")

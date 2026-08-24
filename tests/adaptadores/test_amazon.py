from datetime import UTC, datetime
from pathlib import Path

import pytest

from ddr5_radar.coleta.adaptadores.amazon import extrair_do_html
from ddr5_radar.contrato import ColetaBloqueada

FIXTURE = Path(__file__).parent.parent / "fixtures" / "amazon_busca_ddr5.html"


@pytest.fixture
def ofertas():
    return extrair_do_html(FIXTURE.read_text(encoding="utf-8"), datetime.now(UTC))


def test_encontra_produtos(ofertas):
    assert len(ofertas) >= 10


def test_asin_tem_dez_caracteres(ofertas):
    for oferta in ofertas:
        assert len(oferta.id_na_loja) == 10


def test_preco_brasileiro_vira_centavos(ofertas):
    for oferta in ofertas:
        assert isinstance(oferta.preco_centavos, int)
        assert oferta.preco_centavos > 1000  # nenhuma DDR5 custa menos de R$ 10


def test_url_absoluta_de_produto(ofertas):
    for oferta in ofertas:
        assert oferta.url.startswith("https://www.amazon.com.br/")
        assert "/dp/" in oferta.url


def test_titulo_nao_vem_vazio(ofertas):
    assert all(len(o.titulo.strip()) > 10 for o in ofertas)


def test_captcha_classico_vira_bloqueio():
    html = '<html><form action="/errors/validateCaptcha">...</form></html>'
    with pytest.raises(ColetaBloqueada, match="captcha"):
        extrair_do_html(html, datetime.now(UTC))


def test_desafio_do_akamai_vira_bloqueio():
    # resposta real de 2026-08-24: 2 KB com meta refresh e bm-verify.
    # Sem esta deteccao o coletor registraria "0 ofertas" como se fosse normal.
    html = (
        '<html><head><meta http-equiv="refresh" content="5; '
        "URL='/s?k=memoria+ddr5&bm-verify=AAQAAAAN'\" /></head>"
        "<body><script>function triggerInterstitialChallenge(){}</script></body></html>"
    )
    with pytest.raises(ColetaBloqueada, match="desafio"):
        extrair_do_html(html, datetime.now(UTC))


def test_pagina_sem_resultado_nem_bloqueio_e_lista_vazia():
    html = "<html><body><div>Nenhum resultado</div></body></html>"
    assert extrair_do_html(html, datetime.now(UTC)) == []

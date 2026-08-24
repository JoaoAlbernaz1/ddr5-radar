from datetime import UTC, datetime
from pathlib import Path

import pytest

from ddr5_radar.coleta.adaptadores.terabyte import extrair_do_html
from ddr5_radar.contrato import ColetaBloqueada

FIXTURE = Path(__file__).parent.parent / "fixtures" / "terabyte_busca_ddr5.html"


@pytest.fixture
def ofertas():
    return extrair_do_html(FIXTURE.read_text(encoding="utf-8"), datetime.now(UTC))


def test_encontra_produtos(ofertas):
    assert len(ofertas) >= 20


def test_preco_em_centavos_inteiros(ofertas):
    for oferta in ofertas:
        assert isinstance(oferta.preco_centavos, int)
        assert oferta.preco_centavos > 1000


def test_url_absoluta_de_produto(ofertas):
    for oferta in ofertas:
        assert oferta.url.startswith("https://www.terabyteshop.com.br/produto/")


def test_id_na_loja_nao_repete(ofertas):
    ids = [o.id_na_loja for o in ofertas]
    assert len(ids) == len(set(ids))


def test_titulo_preenchido(ofertas):
    assert all(len(o.titulo.strip()) > 10 for o in ofertas)


def test_traz_memoria_de_verdade(ofertas):
    titulos = " ".join(o.titulo.lower() for o in ofertas)
    assert "memória ddr5" in titulos or "memoria ddr5" in titulos


def test_card_sem_preco_e_ignorado():
    html = """
    <div class="product-item">
      <a class="product-item__name" href="/produto/1/pc-custom">PC Gamer Custom Monte do seu jeito</a>
      <div class="product-item__new-price">Monte do seu jeito</div>
    </div>
    """
    assert extrair_do_html(html, datetime.now(UTC)) == []


def test_html_sem_card_nenhum_vira_bloqueio():
    with pytest.raises(ColetaBloqueada):
        extrair_do_html("<html><body></body></html>", datetime.now(UTC))

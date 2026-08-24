from datetime import UTC, datetime
from pathlib import Path

import pytest

from ddr5_radar.coleta.adaptadores.kabum import extrair_do_html
from ddr5_radar.contrato import ColetaBloqueada, Condicao

FIXTURE = Path(__file__).parent.parent / "fixtures" / "kabum_busca_ddr5.html"


@pytest.fixture
def ofertas():
    html = FIXTURE.read_text(encoding="utf-8")
    return extrair_do_html(html, datetime.now(UTC))


def test_encontra_produtos(ofertas):
    assert len(ofertas) >= 20


def test_preco_vem_em_centavos_inteiros(ofertas):
    for oferta in ofertas:
        assert isinstance(oferta.preco_centavos, int)
        assert oferta.preco_centavos > 0


def test_url_do_produto_e_absoluta(ofertas):
    for oferta in ofertas:
        assert oferta.url.startswith("https://www.kabum.com.br/produto/")


def test_id_na_loja_e_o_codigo_kabum(ofertas):
    for oferta in ofertas:
        assert oferta.id_na_loja.isdigit()


def test_todas_marcadas_como_kabum(ofertas):
    assert {o.loja for o in ofertas} == {"kabum"}


def test_condicao_padrao_e_novo(ofertas):
    assert all(
        o.condicao is Condicao.NOVO
        for o in ofertas
        if "openbox" not in o.titulo.lower()
    )


def test_html_sem_next_data_denuncia_bloqueio():
    with pytest.raises(ColetaBloqueada, match="__NEXT_DATA__"):
        extrair_do_html("<html><body>Acesso negado</body></html>", datetime.now(UTC))

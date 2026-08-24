"""Batem nas lojas de verdade. Rodar com: pytest -m rede

Nao rodam na suite normal nem no CI. Servem para responder uma pergunta
so: "a loja mudou de formato?"
"""
import pytest

from ddr5_radar.coleta.adaptadores import ADAPTADORES

pytestmark = pytest.mark.rede


@pytest.mark.parametrize("nome", sorted(ADAPTADORES))
async def test_loja_ainda_devolve_produto(nome):
    ofertas = await ADAPTADORES[nome].buscar("ddr5")

    assert len(ofertas) >= 5, f"{nome} devolveu {len(ofertas)} ofertas"
    primeira = ofertas[0]
    assert primeira.preco_centavos > 1000
    assert primeira.titulo.strip()
    assert primeira.url.startswith("https://")
    assert primeira.id_na_loja


@pytest.mark.parametrize("nome", sorted(ADAPTADORES))
async def test_titulos_parecem_memoria(nome):
    ofertas = await ADAPTADORES[nome].buscar("ddr5")
    com_ddr5 = [o for o in ofertas if "ddr5" in o.titulo.lower()]
    assert len(com_ddr5) >= len(ofertas) // 2, (
        f"{nome}: só {len(com_ddr5)} de {len(ofertas)} títulos mencionam DDR5 — "
        "a busca pode ter mudado de comportamento"
    )

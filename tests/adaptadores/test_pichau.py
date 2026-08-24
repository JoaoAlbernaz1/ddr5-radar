"""A Pichau nao permitiu capturar fixture de listagem (bloqueio intermitente).

Estes testes cobrem o que da para cobrir sem ela: a deteccao de bloqueio e a
leitura de preco no formato "de R$ X por R$ Y", que foi observado no HTML real
em 2026-08-24. O teste de listagem so roda quando a fixture existir.
"""
from datetime import UTC, datetime
from pathlib import Path

import pytest

from ddr5_radar.coleta.adaptadores.pichau import extrair_do_html, ler_precos
from ddr5_radar.contrato import ColetaBloqueada

FIXTURE = Path(__file__).parent.parent / "fixtures" / "pichau_lista_memoria.html"


def test_pagina_de_manutencao_vira_bloqueio():
    html = "<html><head><title>Site em Manutenção - Pru Pru</title></head><body></body></html>"
    with pytest.raises(ColetaBloqueada, match="Manuten"):
        extrair_do_html(html, datetime.now(UTC))


def test_pagina_404_vira_bloqueio():
    html = "<html><head><title>404 - Página não encontrada | Pichau</title></head></html>"
    with pytest.raises(ColetaBloqueada, match="404"):
        extrair_do_html(html, datetime.now(UTC))


def test_le_preco_no_padrao_de_por():
    # texto real de card observado em 2026-08-24
    texto = "33%OFF90UNIDVentoinha Pichau Ventus NX deR$ 70,58porR$ 39,99À vista"
    atual, cheio = ler_precos(texto)
    assert atual == 3999
    assert cheio == 7058


def test_le_preco_quando_nao_ha_desconto():
    atual, cheio = ler_precos("Memória Kingston Fury Beast 16GB DDR5 R$ 1.899,99 À vista")
    assert atual == 189999
    assert cheio is None


def test_card_sem_preco_nenhum_e_ignorado():
    assert ler_precos("Memória Kingston Fury Beast 16GB DDR5 Avise-me") == (None, None)


@pytest.mark.skipif(not FIXTURE.exists(), reason="fixture da Pichau ainda nao capturada")
def test_extrai_listagem_quando_a_fixture_existir():
    ofertas = extrair_do_html(FIXTURE.read_text(encoding="utf-8"), datetime.now(UTC))
    assert len(ofertas) >= 10
    assert all(o.url.startswith("https://www.pichau.com.br/") for o in ofertas)
    assert all(o.preco_centavos > 1000 for o in ofertas)

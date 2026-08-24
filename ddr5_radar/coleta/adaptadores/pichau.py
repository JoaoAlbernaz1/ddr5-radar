"""Pichau: a loja mais hostil das cinco.

Reconhecimento de 2026-08-24:
  - headless=True devolve "Site em Manutencao - Pru Pru"; headed carrega
  - o bloqueio e intermitente mesmo com navegador visivel
  - as classes CSS sao hasheadas pelo MUI e mudam a cada build deles

Por isso nada aqui depende de nome de classe legivel: o card e localizado
pela classe estrutural do grid do MUI, o titulo por <h2>, o link por
<a href>, e o preco por regex no texto -- padrao "de R$ X por R$ Y".

Esta loja NAO esta no registro ADAPTADORES. Para liga-la, capture uma
fixture de listagem que funcione e acrescente-a la.
"""
import re
from datetime import UTC, datetime
from urllib.parse import urljoin

from selectolax.parser import HTMLParser

from ddr5_radar.coleta.navegador import abrir_navegador
from ddr5_radar.contrato import (
    ColetaBloqueada, Condicao, OfertaCrua, reais_para_centavos,
)

BASE = "https://www.pichau.com.br"
LISTAGEM = f"{BASE}/hardware/memorias"

SELETOR_CARD = "div[class*='MuiGrid2-grid-lg-3']"
PRECO_POR = re.compile(r"por\s*R\$\s*([\d.,]+)", re.I)
PRECO_DE = re.compile(r"\bde\s*R\$\s*([\d.,]+)", re.I)
PRECO_QUALQUER = re.compile(r"R\$\s*([\d.,]+)")


def ler_precos(texto: str) -> tuple[int | None, int | None]:
    """Devolve (preco_atual, preco_cheio) em centavos.

    Na Pichau o card escreve "de R$ 70,58 por R$ 39,99" quando ha desconto,
    e so um "R$ X" quando nao ha.
    """
    por = PRECO_POR.search(texto)
    de = PRECO_DE.search(texto)
    if por:
        atual = reais_para_centavos(por.group(1))
        cheio = reais_para_centavos(de.group(1)) if de else None
        return atual, (cheio if cheio and cheio > atual else None)

    qualquer = PRECO_QUALQUER.search(texto)
    return (reais_para_centavos(qualquer.group(1)), None) if qualquer else (None, None)


def extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]:
    arvore = HTMLParser(html)
    titulo_pagina = arvore.css_first("title")
    rotulo = titulo_pagina.text() if titulo_pagina else ""
    if "Manuten" in rotulo:
        raise ColetaBloqueada("Pichau devolveu a pagina de Manutencao (anti-bot)")
    if "404" in rotulo:
        raise ColetaBloqueada("Pichau devolveu 404 — URL de listagem mudou ou bloqueio")

    ofertas = []
    for card in arvore.css(SELETOR_CARD):
        link = card.css_first("a[href]")
        titulo = card.css_first("h2")
        if not (link and titulo):
            continue

        atual, cheio = ler_precos(card.text(strip=True))
        if atual is None:
            continue  # sem preco visivel: esgotado ou "avise-me"

        caminho = link.attributes.get("href", "")
        imagem = card.css_first("img")
        ofertas.append(
            OfertaCrua(
                loja="pichau",
                id_na_loja=caminho.strip("/").split("/")[-1],
                titulo=titulo.text(strip=True),
                preco_centavos=atual,
                preco_original_centavos=cheio,
                em_estoque=True,
                url=urljoin(BASE, caminho),
                url_imagem=imagem.attributes.get("src") if imagem else None,
                condicao=Condicao.NOVO,
                vendedor="Pichau",
                reputacao_vendedor=None,
                coletado_em=coletado_em,
            )
        )
    return ofertas


class AdaptadorPichau:
    loja = "pichau"

    async def buscar(self, termo: str) -> list[OfertaCrua]:
        coletado_em = datetime.now(UTC)
        # headless=False de proposito: headless e bloqueado (ver docstring)
        async with abrir_navegador(headless=False) as pagina:
            await pagina.goto(LISTAGEM, wait_until="domcontentloaded", timeout=45_000)
            await pagina.wait_for_timeout(8_000)
            await pagina.mouse.wheel(0, 4_000)
            await pagina.wait_for_timeout(3_000)
            html = await pagina.content()
        return extrair_do_html(html, coletado_em)

"""Terabyte: WAF bloqueia curl (403), mas Playwright headless passa.

Seletores confirmados em 2026-08-24 e legiveis -- nada de classe hasheada,
ao contrario da Pichau.
"""
from datetime import UTC, datetime
from urllib.parse import urljoin

from selectolax.parser import HTMLParser

from ddr5_radar.coleta.navegador import abrir_navegador
from ddr5_radar.contrato import (
    ColetaBloqueada, Condicao, OfertaCrua, reais_para_centavos,
)

BASE = "https://www.terabyteshop.com.br"
BUSCA = f"{BASE}/busca?str={{termo}}"

SELETOR_CARD = "div.product-item"
SELETOR_NOME = "a.product-item__name"
SELETOR_PRECO = "div.product-item__new-price"
SELETOR_PRECO_CHEIO = "div.product-item__old-price"
SELETOR_IMAGEM = "img.image-thumbnail"


def extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]:
    arvore = HTMLParser(html)
    cards = arvore.css(SELETOR_CARD)
    if not cards:
        raise ColetaBloqueada(
            "Terabyte nao devolveu nenhum card — bloqueio ou mudanca de layout"
        )

    ofertas = []
    vistos: set[str] = set()
    for card in cards:
        nome = card.css_first(SELETOR_NOME)
        preco = card.css_first(SELETOR_PRECO)
        if not (nome and preco):
            continue

        texto_preco = preco.text(strip=True)
        if "R$" not in texto_preco:
            continue  # "Monte do seu jeito" (PC custom) ou esgotado

        caminho = nome.attributes.get("href", "")
        partes = caminho.strip("/").split("/")
        if len(partes) < 2:
            continue
        id_na_loja = partes[1]  # /produto/22360/slug
        if id_na_loja in vistos:
            continue  # a pagina repete o card em grades diferentes
        vistos.add(id_na_loja)

        cheio = card.css_first(SELETOR_PRECO_CHEIO)
        imagem = card.css_first(SELETOR_IMAGEM)
        preco_centavos = reais_para_centavos(texto_preco)
        cheio_centavos = (
            reais_para_centavos(cheio.text(strip=True))
            if cheio and "R$" in cheio.text()
            else None
        )

        ofertas.append(
            OfertaCrua(
                loja="terabyte",
                id_na_loja=id_na_loja,
                titulo=nome.text(strip=True),
                preco_centavos=preco_centavos,
                preco_original_centavos=(
                    cheio_centavos
                    if cheio_centavos and cheio_centavos > preco_centavos
                    else None
                ),
                em_estoque=True,
                url=urljoin(BASE, caminho),
                url_imagem=(
                    imagem.attributes.get("data-src") or imagem.attributes.get("src")
                    if imagem
                    else None
                ),
                condicao=Condicao.NOVO,
                vendedor="TerabyteShop",
                reputacao_vendedor=None,
                coletado_em=coletado_em,
            )
        )
    return ofertas


class AdaptadorTerabyte:
    loja = "terabyte"

    async def buscar(self, termo: str) -> list[OfertaCrua]:
        coletado_em = datetime.now(UTC)
        async with abrir_navegador() as pagina:  # headless funciona aqui
            await pagina.goto(
                BUSCA.format(termo=termo), wait_until="domcontentloaded", timeout=45_000
            )
            await pagina.wait_for_timeout(5_000)
            html = await pagina.content()
        return extrair_do_html(html, coletado_em)

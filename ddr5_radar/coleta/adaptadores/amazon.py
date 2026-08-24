"""Amazon BR: precisa de navegador.

Em 2026-08-24 a busca via httpx passou a devolver o desafio do Akamai
(2 KB com meta refresh e bm-verify) enquanto o Playwright headless
trazia os 60 produtos normalmente. Por isso aqui e navegador, nao httpx.

O desafio nao usa o captcha classico ("validateCaptcha"), entao detectar
so aquele deixaria o coletor registrar "0 ofertas" como se fosse normal.
"""
import asyncio
from datetime import UTC, datetime
from urllib.parse import urljoin

from selectolax.parser import HTMLParser

from ddr5_radar.coleta.navegador import abrir_navegador
from ddr5_radar.contrato import (
    ColetaBloqueada, Condicao, OfertaCrua, reais_para_centavos,
)

BASE = "https://www.amazon.com.br"
BUSCA = f"{BASE}/s?k={{termo}}&page={{pagina}}"
PAGINAS = 3
PAUSA_SEGUNDOS = 2.0

SELETOR_CARD = 'div[data-component-type="s-search-result"]'


def extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]:
    if "validateCaptcha" in html or "Digite os caracteres" in html:
        raise ColetaBloqueada("Amazon serviu captcha")
    if "bm-verify" in html or "triggerInterstitialChallenge" in html:
        raise ColetaBloqueada("Amazon serviu o desafio do Akamai (bm-verify)")

    arvore = HTMLParser(html)
    ofertas = []
    for card in arvore.css(SELETOR_CARD):
        asin = card.attributes.get("data-asin", "")
        if len(asin) != 10:
            continue

        titulo_no = card.css_first("h2")
        preco_no = card.css_first(".a-price > .a-offscreen")
        link_no = card.css_first('a[href*="/dp/"]')
        if not (titulo_no and preco_no and link_no):
            continue  # patrocinado sem preco, banner, ou card incompleto

        cheio_no = card.css_first(".a-price.a-text-price > .a-offscreen")
        imagem_no = card.css_first("img.s-image")
        preco_centavos = reais_para_centavos(preco_no.text(strip=True))
        cheio_centavos = (
            reais_para_centavos(cheio_no.text(strip=True)) if cheio_no else None
        )

        ofertas.append(
            OfertaCrua(
                loja="amazon",
                id_na_loja=asin,
                titulo=titulo_no.text(strip=True),
                preco_centavos=preco_centavos,
                preco_original_centavos=(
                    cheio_centavos
                    if cheio_centavos and cheio_centavos > preco_centavos
                    else None
                ),
                em_estoque=True,  # a busca so lista o que da para comprar
                url=urljoin(BASE, link_no.attributes.get("href", "")).split("?")[0],
                url_imagem=imagem_no.attributes.get("src") if imagem_no else None,
                condicao=Condicao.NOVO,
                vendedor=None,  # a busca nao expoe vendedor de forma confiavel
                reputacao_vendedor=None,
                coletado_em=coletado_em,
            )
        )
    return ofertas


class AdaptadorAmazon:
    loja = "amazon"

    async def buscar(self, termo: str) -> list[OfertaCrua]:
        coletado_em = datetime.now(UTC)
        todas: list[OfertaCrua] = []
        async with abrir_navegador() as pagina:
            for numero in range(1, PAGINAS + 1):
                if numero > 1:
                    await asyncio.sleep(PAUSA_SEGUNDOS)
                await pagina.goto(
                    BUSCA.format(termo=termo, pagina=numero),
                    wait_until="domcontentloaded",
                    timeout=45_000,
                )
                await pagina.wait_for_timeout(4_000)
                da_pagina = extrair_do_html(await pagina.content(), coletado_em)
                if not da_pagina:
                    break
                todas.extend(da_pagina)
        return todas

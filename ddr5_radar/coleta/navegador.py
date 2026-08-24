"""Contexto Playwright unico, usado pelas lojas que bloqueiam HTTP simples.

Abrir um Chromium por loja custaria o dobro de memoria e de tempo no
runner do GitHub Actions.

headless=False existe por causa da Pichau: com headless=True ela devolve
a pagina de manutencao (verificado em 2026-08-24). Amazon e Terabyte
funcionam headless.
"""
from contextlib import asynccontextmanager

from playwright.async_api import Page, async_playwright

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
)


@asynccontextmanager
async def abrir_navegador(headless: bool = True):
    async with async_playwright() as p:
        navegador = await p.chromium.launch(
            headless=headless,
            args=["--disable-blink-features=AutomationControlled"],
        )
        contexto = await navegador.new_context(
            user_agent=UA,
            locale="pt-BR",
            viewport={"width": 1440, "height": 1000},
            extra_http_headers={"Accept-Language": "pt-BR,pt;q=0.9"},
        )
        await contexto.add_init_script(
            "Object.defineProperty(navigator,'webdriver',{get:()=>undefined})"
        )
        pagina: Page = await contexto.new_page()
        try:
            yield pagina
        finally:
            await contexto.close()
            await navegador.close()

"""Baixa a pagina de busca de uma loja e salva em tests/fixtures/.

Uso: python scripts/capturar_fixture.py kabum
As lojas com anti-bot (pichau, terabyte) sao capturadas via Playwright.
A Pichau exige navegador visivel; a Terabyte funciona headless.
"""
import asyncio
import sys
from pathlib import Path

import httpx

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
)
DESTINO = Path(__file__).parent.parent / "tests" / "fixtures"

URLS_HTTP = {
    "kabum": "https://www.kabum.com.br/busca/ddr5",
}
# A Amazon passou a servir o desafio do Akamai (bm-verify) para cliente HTTP
# puro em 2026-08-24; com navegador ela responde normal.
URLS_NAVEGADOR = {
    "amazon": "https://www.amazon.com.br/s?k=memoria+ddr5",
    "pichau": "https://www.pichau.com.br/hardware/memorias",
    "terabyte": "https://www.terabyteshop.com.br/busca?str=ddr5",
}


async def capturar(loja: str) -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    arquivo = DESTINO / f"{loja}_busca_ddr5.html"

    if loja in URLS_HTTP:
        async with httpx.AsyncClient(
            headers={"User-Agent": UA, "Accept-Language": "pt-BR,pt;q=0.9"},
            follow_redirects=True, timeout=30,
        ) as cliente:
            resposta = await cliente.get(URLS_HTTP[loja])
            resposta.raise_for_status()
            arquivo.write_text(resposta.text, encoding="utf-8")
    else:
        from playwright.async_api import async_playwright

        # A Pichau bloqueia headless (verificado em 2026-08-24); a Terabyte nao.
        async with async_playwright() as p:
            navegador = await p.chromium.launch(headless=(loja != "pichau"))
            pagina = await navegador.new_page(user_agent=UA, locale="pt-BR")
            await pagina.goto(URLS_NAVEGADOR[loja], wait_until="domcontentloaded", timeout=45_000)
            await pagina.wait_for_timeout(8_000)
            await pagina.mouse.wheel(0, 4_000)
            await pagina.wait_for_timeout(3_000)
            arquivo.write_text(await pagina.content(), encoding="utf-8")
            await navegador.close()

    print(f"{arquivo} — {arquivo.stat().st_size} bytes")


if __name__ == "__main__":
    asyncio.run(capturar(sys.argv[1]))

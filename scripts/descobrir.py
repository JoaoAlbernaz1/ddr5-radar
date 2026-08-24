"""Captura o HTML renderizado das lojas bloqueadas e mostra os candidatos a card."""
import asyncio, re, sys
from collections import Counter
from pathlib import Path
from playwright.async_api import async_playwright
from selectolax.parser import HTMLParser

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
LOJAS = {
    "pichau": "https://www.pichau.com.br/hardware/memorias/memoria-ddr5",
    "terabyte": "https://www.terabyteshop.com.br/busca?str=ddr5",
}
PRECO = re.compile(r"R\$\s*\d")

async def capturar(nome, url, pagina):
    try:
        await pagina.goto(url, wait_until="domcontentloaded", timeout=45_000)
        await pagina.wait_for_timeout(6000)
        html = await pagina.content()
    except Exception as e:
        print(f"!! {nome}: {type(e).__name__}: {str(e)[:150]}")
        return
    destino = Path("tests/fixtures") / f"{nome}_busca_ddr5.html"
    destino.write_text(html, encoding="utf-8")
    print(f"\n===== {nome}: {len(html)} bytes -> {destino}")
    if "Manuten" in html and len(html) < 100_000:
        print("   BLOQUEADO (pagina de manutencao)")
        return

    arvore = HTMLParser(html)
    contagem, exemplo = Counter(), {}
    for no in arvore.css("div, li, article"):
        texto = no.text(strip=True)
        if not PRECO.search(texto) or len(texto) > 350 or not no.css_first("a[href]"):
            continue
        assinatura = f"{no.tag}.{no.attributes.get('class') or '(sem-classe)'}"
        contagem[assinatura] += 1
        exemplo.setdefault(assinatura, texto[:130])
    for assinatura, qtd in contagem.most_common(6):
        print(f"  {qtd:>4}x  {assinatura[:120]}")
        print(f"        {exemplo[assinatura]}")

async def main():
    async with async_playwright() as p:
        nav = await p.chromium.launch(args=["--disable-blink-features=AutomationControlled"])
        ctx = await nav.new_context(user_agent=UA, locale="pt-BR",
                                    viewport={"width": 1366, "height": 900})
        pagina = await ctx.new_page()
        for nome, url in LOJAS.items():
            await capturar(nome, url, pagina)
        await nav.close()

asyncio.run(main())

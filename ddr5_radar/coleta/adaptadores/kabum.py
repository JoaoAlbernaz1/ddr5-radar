"""Kabum: o HTML da busca carrega um JSON completo no __NEXT_DATA__.

Nao ha API publica; este JSON e o que a propria pagina usa para renderizar.
"""
import asyncio
import json
import re
from datetime import UTC, datetime

import httpx

from ddr5_radar.contrato import (
    ColetaBloqueada, Condicao, OfertaCrua, reais_para_centavos,
)

BASE = "https://www.kabum.com.br"
UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
)
PADRAO_NEXT_DATA = re.compile(
    r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', re.S
)
PAGINAS = 3           # spec §6: no maximo 3 paginas por rodada
PAUSA_SEGUNDOS = 2.0  # spec §6: ritmo respeitoso


def extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]:
    achado = PADRAO_NEXT_DATA.search(html)
    if not achado:
        raise ColetaBloqueada(
            "Kabum nao devolveu __NEXT_DATA__ — provavelmente bloqueio ou "
            "mudanca de layout"
        )
    dados = json.loads(achado.group(1))
    try:
        itens = dados["props"]["pageProps"]["data"]["catalogServer"]["data"]
    except (KeyError, TypeError) as erro:
        raise ColetaBloqueada(f"Formato do __NEXT_DATA__ mudou: {erro}") from erro

    ofertas = []
    for item in itens:
        preco = item.get("priceWithDiscount") or item.get("price")
        if not preco:
            continue
        cheio = item.get("price")
        flags = item.get("flags") or {}
        ofertas.append(
            OfertaCrua(
                loja="kabum",
                id_na_loja=str(item["code"]),
                titulo=item["name"],
                preco_centavos=reais_para_centavos(preco),
                preco_original_centavos=(
                    reais_para_centavos(cheio) if cheio and cheio != preco else None
                ),
                em_estoque=bool(item.get("available")),
                url=f"{BASE}/produto/{item['code']}/{item.get('friendlyName', '')}",
                url_imagem=item.get("image"),
                condicao=(
                    Condicao.RECONDICIONADO if flags.get("isOpenbox") else Condicao.NOVO
                ),
                vendedor=item.get("sellerName"),
                reputacao_vendedor=None,
                coletado_em=coletado_em,
            )
        )
    return ofertas


class AdaptadorKabum:
    loja = "kabum"

    async def buscar(self, termo: str) -> list[OfertaCrua]:
        coletado_em = datetime.now(UTC)
        todas: list[OfertaCrua] = []
        async with httpx.AsyncClient(
            headers={"User-Agent": UA, "Accept-Language": "pt-BR,pt;q=0.9"},
            follow_redirects=True, timeout=30,
        ) as cliente:
            for pagina in range(1, PAGINAS + 1):
                if pagina > 1:
                    await asyncio.sleep(PAUSA_SEGUNDOS)
                resposta = await cliente.get(
                    f"{BASE}/busca/{termo}",
                    params={"page_number": pagina, "page_size": 100},
                )
                if resposta.status_code == 403:
                    raise ColetaBloqueada("Kabum respondeu 403")
                resposta.raise_for_status()
                da_pagina = extrair_do_html(resposta.text, coletado_em)
                if not da_pagina:
                    break
                todas.extend(da_pagina)
        return todas

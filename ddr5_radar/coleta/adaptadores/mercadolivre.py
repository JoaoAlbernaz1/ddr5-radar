"""Mercado Livre: unica loja com API oficial -- e a unica que exige token.

A busca publica sem autenticacao passou a responder 403 (verificado em
2026-08-24). O token vem de um app gratuito, fluxo client_credentials.
"""
import asyncio
from datetime import UTC, datetime

import httpx

from ddr5_radar.config import carregar_config
from ddr5_radar.contrato import (
    AdaptadorNaoConfigurado, ColetaBloqueada, Condicao, OfertaCrua,
    reais_para_centavos,
)

API = "https://api.mercadolibre.com"
PAGINAS = 3
POR_PAGINA = 50
PAUSA_SEGUNDOS = 2.0

CONDICOES = {
    "new": Condicao.NOVO,
    "used": Condicao.USADO,
    "refurbished": Condicao.RECONDICIONADO,
}


def converter_resultado(item: dict, coletado_em: datetime) -> OfertaCrua:
    vendedor = item.get("seller") or {}
    original = item.get("original_price")
    return OfertaCrua(
        loja="mercadolivre",
        id_na_loja=item["id"],
        titulo=item["title"],
        preco_centavos=reais_para_centavos(item["price"]),
        preco_original_centavos=reais_para_centavos(original) if original else None,
        em_estoque=int(item.get("available_quantity", 0)) > 0,
        url=item["permalink"],
        url_imagem=item.get("thumbnail"),
        condicao=CONDICOES.get(item.get("condition", ""), Condicao.DESCONHECIDO),
        vendedor=vendedor.get("nickname"),
        reputacao_vendedor=None,  # a busca nao traz; o Plano 2 busca sob demanda
        coletado_em=coletado_em,
    )


class AdaptadorMercadoLivre:
    loja = "mercadolivre"

    async def buscar(self, termo: str) -> list[OfertaCrua]:
        config = carregar_config()
        if not (config.ml_client_id and config.ml_client_secret):
            raise AdaptadorNaoConfigurado(
                "Faltam ML_CLIENT_ID e ML_CLIENT_SECRET. Crie um app gratuito em "
                "https://developers.mercadolivre.com.br e guarde nos Secrets."
            )

        coletado_em = datetime.now(UTC)
        async with httpx.AsyncClient(timeout=30) as cliente:
            token = await self._token(
                cliente, config.ml_client_id, config.ml_client_secret
            )
            todas: list[OfertaCrua] = []
            for pagina in range(PAGINAS):
                if pagina:
                    await asyncio.sleep(PAUSA_SEGUNDOS)
                resposta = await cliente.get(
                    f"{API}/sites/MLB/search",
                    params={
                        "q": termo,
                        "limit": POR_PAGINA,
                        "offset": pagina * POR_PAGINA,
                    },
                    headers={"Authorization": f"Bearer {token}"},
                )
                if resposta.status_code in (401, 403):
                    raise ColetaBloqueada(
                        f"Mercado Livre recusou a busca ({resposta.status_code})"
                    )
                resposta.raise_for_status()
                resultados = resposta.json().get("results", [])
                if not resultados:
                    break
                todas.extend(converter_resultado(i, coletado_em) for i in resultados)
        return todas

    async def _token(
        self, cliente: httpx.AsyncClient, client_id: str, secret: str
    ) -> str:
        resposta = await cliente.post(
            f"{API}/oauth/token",
            data={
                "grant_type": "client_credentials",
                "client_id": client_id,
                "client_secret": secret,
            },
        )
        if resposta.status_code != 200:
            raise ColetaBloqueada(
                f"Mercado Livre negou o token: {resposta.text[:200]}"
            )
        return resposta.json()["access_token"]

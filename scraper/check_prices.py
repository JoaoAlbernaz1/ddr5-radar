"""Varre a KaBuM pelo nome de cada peça monitorada no PartWatch e atualiza
preço/histórico/alertas no Supabase.

Porta o adaptador original do ddr5-radar (ddr5_radar/coleta/adaptadores/kabum.py):
a página de busca da KaBuM carrega um JSON completo em __NEXT_DATA__, não
precisa de API nem de parsing de HTML renderizado — só uma requisição HTTP
simples com um User-Agent de navegador de verdade.

Roda via GitHub Actions (.github/workflows/check-prices.yml), não pela
Supabase Edge Function — Deno Edge não tem runtime de navegador e o IP
dela toma 403 da KaBuM com mais força que o do runner do GitHub Actions.

Variáveis de ambiente necessárias (configuradas como Secrets no repo):
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY  (bypassa RLS — é o que permite escrever pra
                               peças de qualquer usuário)
"""
import json
import os
import re
import sys
import time
import unicodedata
from decimal import ROUND_HALF_UP, Decimal
from urllib.parse import quote

import httpx
from supabase import Client, create_client

BASE = "https://www.kabum.com.br"
UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
)
PADRAO_NEXT_DATA = re.compile(
    r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', re.S
)
PAUSA_SEGUNDOS = 2.0  # ritmo respeitoso com a loja, igual ao scraper original


class ColetaBloqueada(Exception):
    """A loja respondeu, mas com bloqueio (403, captcha, manutenção).

    Diferente de um erro de programação: seguimos pra próxima peça.
    """


def reais_para_centavos(valor) -> int:
    if isinstance(valor, str):
        limpo = re.sub(r"[^\d,.-]", "", valor)
        if "," in limpo:
            limpo = limpo.replace(".", "").replace(",", ".")
        valor = limpo or "0"
    centavos = Decimal(str(valor)) * 100
    return int(centavos.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def _tokens_produto(texto: str) -> list[str]:
    """Normalize punctuation and accents without guessing product equivalence."""
    sem_acentos = "".join(
        char for char in unicodedata.normalize("NFKD", texto)
        if not unicodedata.combining(char)
    )
    return re.findall(r"[a-z0-9]+", sem_acentos.lower())


def corresponde_produto(termo: str, nome_produto: str) -> bool:
    """Conservative token match: never substitute an unrelated model.

    More than one matching listing is considered ambiguous and ignored by
    buscar_kabum. This does not guarantee identical SKU or capacities; a
    stable store product identifier is needed before fully autonomous writes.
    """
    procurados = set(_tokens_produto(termo))
    encontrados = set(_tokens_produto(nome_produto))
    if len(procurados) < 2:
        return False
    if not any(any(ch.isdigit() for ch in token) for token in procurados):
        return False
    return procurados.issubset(encontrados)


def buscar_kabum(cliente: httpx.Client, termo: str) -> dict | None:
    caminho = f"{BASE}/busca/{quote(termo, safe='')}"
    resposta = cliente.get(caminho, params={"page_number": 1, "page_size": 20})
    if resposta.status_code == 403:
        raise ColetaBloqueada("Kabum respondeu 403")
    resposta.raise_for_status()

    achado = PADRAO_NEXT_DATA.search(resposta.text)
    if not achado:
        raise ColetaBloqueada("Kabum nao devolveu __NEXT_DATA__ (bloqueio ou layout mudou)")

    try:
        dados = json.loads(achado.group(1))
        itens = dados["props"]["pageProps"]["data"]["catalogServer"]["data"]
    except (KeyError, TypeError, ValueError) as erro:
        raise ColetaBloqueada(f"Formato do __NEXT_DATA__ mudou: {erro}") from erro

    if not isinstance(itens, list):
        raise ColetaBloqueada("Catalogo nao retornou uma lista de produtos")

    correspondencias = []
    for item in itens:
        if not isinstance(item, dict) or not item.get("available"):
            continue
        nome = item.get("name")
        if not isinstance(nome, str) or not corresponde_produto(termo, nome):
            continue
        preco = item.get("priceWithDiscount") or item.get("price")
        if preco is None:
            continue
        centavos = reais_para_centavos(preco)
        if centavos <= 0:
            continue
        correspondencias.append({"nome": nome, "preco": centavos / 100})

    # Empty or ambiguous results must not update prices.
    if len(correspondencias) != 1:
        print(
            f"  nenhuma correspondencia unica e verificavel: "
            f"{len(correspondencias)} candidatos"
        )
        return None
    return correspondencias[0]


def processar_peca(supabase: Client, cliente_http: httpx.Client, peca: dict) -> str:
    nome = peca["name"]
    loja = "".join(_tokens_produto(str(peca.get("store", ""))))
    if loja != "kabum":
        print("  loja nao suportada pelo worker KaBuM; sem alteracao")
        return "loja_nao_suportada"
    try:
        achado = buscar_kabum(cliente_http, nome)
    except ColetaBloqueada as erro:
        print(f"  bloqueado: {erro}")
        return "bloqueado"

    if achado is None:
        print("  nao encontrado")
        return "nao_encontrado"

    preco_anterior = float(peca["current_price"])
    novo_preco = achado["preco"]

    if abs(novo_preco - preco_anterior) < 0.01:
        print(f"  sem mudanca (R$ {novo_preco:.2f})")
        return "sem_mudanca"

    supabase.table("parts").update({"current_price": novo_preco}).eq("id", peca["id"]).execute()
    supabase.table("price_history").insert({"part_id": peca["id"], "price": novo_preco}).execute()

    if peca.get("notify_on_drop") and novo_preco < preco_anterior:
        pct = ((novo_preco - preco_anterior) / preco_anterior) * 100
        atingiu_alvo = novo_preco <= float(peca["target_price"])
        mensagem = (
            f"{nome} atingiu seu preço alvo! Agora por R$ {novo_preco:.2f}"
            if atingiu_alvo
            else f"{nome} caiu para R$ {novo_preco:.2f} ({pct:.0f}%)"
        )
        supabase.table("alerts").insert(
            {"user_id": peca["user_id"], "part_id": peca["id"], "message": mensagem}
        ).execute()

    print(f"  atualizado: R$ {preco_anterior:.2f} -> R$ {novo_preco:.2f}")
    return "atualizado"


def main() -> int:
    url = os.environ.get("SUPABASE_URL", "").strip()
    chave = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    missing = [
        name for name, value in (
            ("SUPABASE_URL", url),
            ("SUPABASE_SERVICE_ROLE_KEY", chave),
        ) if not value
    ]
    if missing:
        print(
            "Configuracao incompleta: defina " + ", ".join(missing)
            + " nos secrets do GitHub Actions antes de executar a coleta.",
            file=sys.stderr,
        )
        return 2
    supabase = create_client(url, chave)

    pecas = supabase.table("parts").select("*").execute().data
    print(f"{len(pecas)} peca(s) monitorada(s)")

    resumo = {"atualizado": 0, "sem_mudanca": 0, "nao_encontrado": 0, "bloqueado": 0, "loja_nao_suportada": 0}
    with httpx.Client(
        headers={"User-Agent": UA, "Accept-Language": "pt-BR,pt;q=0.9"},
        follow_redirects=True,
        timeout=30,
    ) as cliente_http:
        for i, peca in enumerate(pecas):
            print(f"[{i + 1}/{len(pecas)}] {peca['name']}")
            status = processar_peca(supabase, cliente_http, peca)
            resumo[status] = resumo.get(status, 0) + 1
            if i < len(pecas) - 1:
                time.sleep(PAUSA_SEGUNDOS)

    print("Resumo:", resumo)
    return 0


if __name__ == "__main__":
    sys.exit(main())

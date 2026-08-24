"""Ponto de entrada da coleta. O unico arquivo que conhece todas as camadas."""
import argparse
import asyncio
import sys

from ddr5_radar.coleta.adaptadores import ADAPTADORES
from ddr5_radar.coleta.executor import coletar_tudo
from ddr5_radar.nucleo.db import criar_sessao
from ddr5_radar.persistencia import (
    finalizar_rodada, gravar_ofertas, iniciar_rodada, registrar_saude,
)

TERMO_PADRAO = "ddr5"


async def executar_coleta(termo: str, lojas: list[str] | None = None) -> str:
    escolhidos = [
        adaptador
        for nome, adaptador in ADAPTADORES.items()
        if lojas is None or nome in lojas
    ]
    resultados = await coletar_tudo(termo, escolhidos)

    fabrica = criar_sessao()
    with fabrica() as sessao:
        rodada = iniciar_rodada(sessao)
        for resultado in resultados:
            registrar_saude(
                sessao, rodada, resultado.loja, resultado.sucesso,
                len(resultado.ofertas), resultado.erro, resultado.duracao_ms,
            )
        todas = [o for r in resultados for o in r.ofertas]
        resumo = gravar_ofertas(sessao, rodada, todas)
        finalizar_rodada(sessao, rodada, resumo)

    linhas = [
        f"Rodada: {resumo.ofertas_novas} nova(s), "
        f"{resumo.ofertas_atualizadas} atualizada(s), "
        f"{resumo.precos_gravados} preço(s) gravado(s), "
        f"{resumo.descartadas} descartada(s) por não ser memória DDR5"
    ]
    for resultado in resultados:
        marca = "ok " if resultado.sucesso else "FALHOU"
        detalhe = f" — {resultado.erro}" if resultado.erro else ""
        linhas.append(
            f"  {marca} {resultado.loja}: {len(resultado.ofertas)} "
            f"({resultado.duracao_ms}ms){detalhe}"
        )
    return "\n".join(linhas)


def principal() -> int:
    parser = argparse.ArgumentParser(prog="ddr5-radar")
    sub = parser.add_subparsers(dest="comando", required=True)
    coletar = sub.add_parser("coletar", help="roda uma rodada de coleta")
    coletar.add_argument("--termo", default=TERMO_PADRAO)
    coletar.add_argument(
        "--loja", action="append", dest="lojas",
        help="limita a uma loja (pode repetir)",
    )
    argumentos = parser.parse_args()

    resumo = asyncio.run(executar_coleta(argumentos.termo, argumentos.lojas))
    print(resumo)
    return 0


if __name__ == "__main__":
    sys.exit(principal())

"""Roda todos os adaptadores em paralelo isolando a falha de cada um.

Loja quebrada nao derruba a rodada (spec §6): quem cai vira
ResultadoLoja(sucesso=False) e as outras seguem. Loja travada e cortada
por timeout -- o runner do Actions nao pode ficar preso esperando.
"""
import asyncio
import time
from dataclasses import dataclass, field

from ddr5_radar.contrato import (
    Adaptador, AdaptadorNaoConfigurado, ColetaBloqueada, OfertaCrua,
)


@dataclass(slots=True)
class ResultadoLoja:
    loja: str
    ofertas: list[OfertaCrua] = field(default_factory=list)
    sucesso: bool = True
    erro: str | None = None
    duracao_ms: int = 0


async def _rodar_um(
    adaptador: Adaptador, termo: str, timeout_segundos: int
) -> ResultadoLoja:
    comeco = time.monotonic()
    try:
        async with asyncio.timeout(timeout_segundos):
            ofertas = await adaptador.buscar(termo)
        return ResultadoLoja(
            loja=adaptador.loja,
            ofertas=ofertas,
            duracao_ms=int((time.monotonic() - comeco) * 1000),
        )
    except TimeoutError:
        erro = f"Estourou o tempo de {timeout_segundos}s"
    except (ColetaBloqueada, AdaptadorNaoConfigurado) as problema:
        erro = str(problema)
    except Exception as inesperado:  # bug no adaptador: contem e reporta
        erro = f"{type(inesperado).__name__}: {inesperado}"

    return ResultadoLoja(
        loja=adaptador.loja,
        sucesso=False,
        erro=erro,
        duracao_ms=int((time.monotonic() - comeco) * 1000),
    )


async def coletar_tudo(
    termo: str, adaptadores: list[Adaptador], timeout_segundos: int = 120
) -> list[ResultadoLoja]:
    return list(
        await asyncio.gather(
            *(_rodar_um(a, termo, timeout_segundos) for a in adaptadores)
        )
    )

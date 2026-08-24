import asyncio
from datetime import UTC, datetime

from ddr5_radar.coleta.executor import coletar_tudo
from ddr5_radar.contrato import (
    AdaptadorNaoConfigurado, ColetaBloqueada, Condicao, OfertaCrua,
)


def _oferta(loja: str) -> OfertaCrua:
    return OfertaCrua(
        loja=loja, id_na_loja="1",
        titulo="Memória DDR5 16GB 5600MHz Kingston Fury Beast",
        preco_centavos=100000, preco_original_centavos=None, em_estoque=True,
        url="https://x", url_imagem=None, condicao=Condicao.NOVO,
        vendedor=None, reputacao_vendedor=None, coletado_em=datetime.now(UTC),
    )


class AdaptadorBom:
    loja = "boa"
    async def buscar(self, termo): return [_oferta("boa")]


class AdaptadorBloqueado:
    loja = "bloqueada"
    async def buscar(self, termo): raise ColetaBloqueada("403 anti-bot")


class AdaptadorSemCredencial:
    loja = "sem_credencial"
    async def buscar(self, termo): raise AdaptadorNaoConfigurado("falta token")


class AdaptadorQuebrado:
    loja = "quebrada"
    async def buscar(self, termo): raise KeyError("campo sumiu")


class AdaptadorLento:
    loja = "lenta"
    async def buscar(self, termo):
        await asyncio.sleep(10)
        return []


async def test_loja_quebrada_nao_derruba_as_outras():
    resultados = await coletar_tudo(
        "ddr5", [AdaptadorBom(), AdaptadorBloqueado(), AdaptadorQuebrado()]
    )
    por_loja = {r.loja: r for r in resultados}

    assert por_loja["boa"].sucesso is True
    assert len(por_loja["boa"].ofertas) == 1
    assert por_loja["bloqueada"].sucesso is False
    assert "403" in por_loja["bloqueada"].erro
    assert por_loja["quebrada"].sucesso is False


async def test_erro_de_programacao_tambem_e_contido():
    resultados = await coletar_tudo("ddr5", [AdaptadorQuebrado()])
    assert resultados[0].sucesso is False
    assert "KeyError" in resultados[0].erro


async def test_falta_de_credencial_e_reportada_como_tal():
    resultados = await coletar_tudo("ddr5", [AdaptadorSemCredencial()])
    assert resultados[0].sucesso is False
    assert "falta token" in resultados[0].erro


async def test_loja_lenta_e_cortada_por_timeout():
    resultados = await coletar_tudo("ddr5", [AdaptadorLento()], timeout_segundos=1)
    assert resultados[0].sucesso is False
    assert "tempo" in resultados[0].erro.lower()


async def test_mede_duracao_de_cada_loja():
    resultados = await coletar_tudo("ddr5", [AdaptadorBom()])
    assert resultados[0].duracao_ms >= 0


async def test_todas_as_lojas_aparecem_no_resultado():
    adaptadores = [AdaptadorBom(), AdaptadorBloqueado(), AdaptadorQuebrado()]
    resultados = await coletar_tudo("ddr5", adaptadores)
    assert len(resultados) == 3

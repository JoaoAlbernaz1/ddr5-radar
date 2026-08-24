"""Grava o resultado de uma rodada de coleta.

Preco so vira linha nova quando muda: sao 144 coletas por dia, e repetir
o mesmo numero 144 vezes nao acrescenta informacao nenhuma.
"""
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from ddr5_radar.contrato import OfertaCrua
from ddr5_radar.nucleo.modelos import Oferta, PrecoObservado, Rodada, SaudeAdaptador
from ddr5_radar.nucleo.normalizador import (
    chave_canonica, eh_ddr5, eh_memoria, extrair_atributos,
)


@dataclass(slots=True)
class ResumoGravacao:
    ofertas_novas: int = 0
    ofertas_atualizadas: int = 0
    precos_gravados: int = 0
    descartadas: int = 0


def iniciar_rodada(sessao: Session) -> Rodada:
    rodada = Rodada(iniciada_em=datetime.now(UTC))
    sessao.add(rodada)
    sessao.flush()
    return rodada


def gravar_ofertas(
    sessao: Session, rodada: Rodada, ofertas: list[OfertaCrua]
) -> ResumoGravacao:
    resumo = ResumoGravacao()
    for crua in ofertas:
        atributos = extrair_atributos(crua.titulo)
        if not eh_ddr5(crua.titulo, atributos) or not eh_memoria(crua.titulo):
            resumo.descartadas += 1
            continue

        oferta = sessao.scalars(
            select(Oferta).where(
                Oferta.loja == crua.loja, Oferta.id_na_loja == crua.id_na_loja
            )
        ).one_or_none()

        if oferta is None:
            oferta = Oferta(
                loja=crua.loja,
                id_na_loja=crua.id_na_loja,
                primeira_vez_em=crua.coletado_em,
                ultima_vez_em=crua.coletado_em,
            )
            sessao.add(oferta)
            resumo.ofertas_novas += 1
        else:
            resumo.ofertas_atualizadas += 1

        oferta.titulo = crua.titulo
        oferta.url = crua.url
        oferta.url_imagem = crua.url_imagem
        oferta.condicao = crua.condicao.value
        oferta.vendedor = crua.vendedor
        oferta.reputacao_vendedor = crua.reputacao_vendedor
        oferta.ultima_vez_em = crua.coletado_em
        oferta.part_number = atributos.part_number
        oferta.chave_canonica = chave_canonica(atributos)
        oferta.marca = atributos.marca
        oferta.linha = atributos.linha
        oferta.capacidade_gb = atributos.capacidade_gb
        oferta.modulos = atributos.modulos
        oferta.velocidade_mts = atributos.velocidade_mts
        oferta.latencia_cl = atributos.latencia_cl
        oferta.formato = atributos.formato.value
        oferta.rgb = atributos.rgb
        sessao.flush()

        if _mudou(sessao, oferta, crua):
            sessao.add(
                PrecoObservado(
                    oferta_id=oferta.id,
                    rodada_id=rodada.id,
                    preco_centavos=crua.preco_centavos,
                    preco_original_centavos=crua.preco_original_centavos,
                    em_estoque=crua.em_estoque,
                    centavos_por_gb=(
                        crua.preco_centavos // atributos.capacidade_gb
                        if atributos.capacidade_gb
                        else None
                    ),
                    observado_em=crua.coletado_em,
                )
            )
            resumo.precos_gravados += 1

    sessao.commit()
    return resumo


def _mudou(sessao: Session, oferta: Oferta, crua: OfertaCrua) -> bool:
    ultimo = sessao.scalars(
        select(PrecoObservado)
        .where(PrecoObservado.oferta_id == oferta.id)
        .order_by(PrecoObservado.observado_em.desc())
        .limit(1)
    ).one_or_none()
    if ultimo is None:
        return True
    return (
        ultimo.preco_centavos != crua.preco_centavos
        or ultimo.em_estoque != crua.em_estoque
    )


def registrar_saude(
    sessao: Session, rodada: Rodada, loja: str, sucesso: bool,
    qtd: int, erro: str | None, duracao_ms: int,
) -> None:
    sessao.add(
        SaudeAdaptador(
            rodada_id=rodada.id, loja=loja, sucesso=sucesso,
            qtd_ofertas=qtd, erro=erro, duracao_ms=duracao_ms,
        )
    )
    sessao.commit()


def finalizar_rodada(sessao: Session, rodada: Rodada, resumo: ResumoGravacao) -> None:
    rodada.terminada_em = datetime.now(UTC)
    rodada.ofertas_vistas = resumo.ofertas_novas + resumo.ofertas_atualizadas
    rodada.precos_gravados = resumo.precos_gravados
    sessao.commit()

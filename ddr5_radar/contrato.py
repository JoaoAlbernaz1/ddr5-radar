"""Vocabulario compartilhado por coleta e nucleo. Nao importa nada do projeto."""
import re
from dataclasses import dataclass
from datetime import datetime
from decimal import ROUND_HALF_UP, Decimal
from enum import StrEnum
from typing import Protocol


class Condicao(StrEnum):
    NOVO = "novo"
    USADO = "usado"
    RECONDICIONADO = "recondicionado"
    DESCONHECIDO = "desconhecido"


class Formato(StrEnum):
    DIMM = "dimm"      # desktop
    SODIMM = "sodimm"  # notebook


@dataclass(frozen=True, slots=True)
class OfertaCrua:
    loja: str
    id_na_loja: str
    titulo: str
    preco_centavos: int
    preco_original_centavos: int | None
    em_estoque: bool
    url: str
    url_imagem: str | None
    condicao: Condicao
    vendedor: str | None
    reputacao_vendedor: float | None
    coletado_em: datetime


class Adaptador(Protocol):
    loja: str

    async def buscar(self, termo: str) -> list[OfertaCrua]: ...


class ColetaBloqueada(Exception):
    """A loja respondeu, mas com bloqueio (403, captcha, pagina de manutencao).

    Diferente de um erro de programacao: o executor registra e segue.
    """


class AdaptadorNaoConfigurado(Exception):
    """Falta credencial para essa loja. Nao e falha, e configuracao ausente."""


def reais_para_centavos(valor: float | str) -> int:
    """Converte via Decimal: 5239.9 * 100 em float da 523989.99..."""
    if isinstance(valor, str):
        limpo = re.sub(r"[^\d,.-]", "", valor)
        if "," in limpo:  # formato brasileiro: 1.899,99
            limpo = limpo.replace(".", "").replace(",", ".")
        valor = limpo or "0"
    centavos = Decimal(str(valor)) * 100
    return int(centavos.quantize(Decimal("1"), rounding=ROUND_HALF_UP))

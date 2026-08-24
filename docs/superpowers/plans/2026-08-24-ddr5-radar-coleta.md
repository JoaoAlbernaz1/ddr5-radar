# DDR5 Radar — Plano 1: Coleta

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Um coletor em Python que, a cada 10 minutos, lê o preço de todas as memórias DDR5 nas lojas brasileiras, identifica qual anúncio é qual produto, e grava tudo em Postgres com histórico. Quatro lojas entram ligadas no v1 (Kabum, Amazon, Mercado Livre, Terabyte); a Pichau fica escrita e desligada até o anti-bot dela permitir capturar uma fixture — ver Task 10.

**Architecture:** Cada loja é um adaptador isolado atrás de um contrato único (`buscar(termo) -> list[OfertaCrua]`), usando httpx, Playwright ou API conforme a loja permita. O executor roda todos os adaptadores isolando a falha de cada um, o normalizador converte títulos livres em identidade de produto (part number e chave canônica), e a persistência grava oferta + preço observado. Roda no GitHub Actions por cron.

**Tech Stack:** Python 3.13, httpx, selectolax, Playwright, SQLAlchemy 2, Alembic, Postgres (Supabase), pytest, respx.

**Spec:** `docs/superpowers/specs/2026-08-24-ddr5-radar-design.md`

**Escopo deste plano:** §4 (pilha), §5 (arquitetura e organização), §6 (coleta), §7 (normalização) da spec. O motor de detecção (§8), a notificação (§9), o painel (§10) e o botão de compra (§11) são o Plano 2 — mas o schema deste plano já nasce com as tabelas deles, conforme §15.

## Global Constraints

- **Python 3.13** — a Vercel aceita 3.12, 3.13 e 3.14; 3.13 é a mais nova com wheels garantidas para Playwright e psycopg, e já está instalada na máquina do João. Não usar sintaxe de 3.14+.
- **Assíncrono em toda a coleta.** Todo adaptador é `async def buscar(...)`. Playwright e httpx são usados nas versões async.
- **Nenhum teste toca a rede**, exceto os marcados `@pytest.mark.rede`, que ficam desmarcados por padrão em `pyproject.toml`.
- **Nenhuma credencial no repositório.** O repo é público. Tudo por variável de ambiente.
- **Ritmo de coleta:** no mínimo 2 segundos entre requisições da mesma loja, no máximo 3 páginas de busca por rodada (spec §6).
- **Dinheiro é sempre `int` em centavos.** Nunca `float`. Conversão só na exibição.
- **Nomes de código em português**, como o resto dos projetos do João. Termos técnicos consagrados (`async`, `commit`, `Protocol`) ficam em inglês.
- **Timestamps sempre com fuso** (`datetime.now(UTC)`), nunca ingênuos.

---

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `pyproject.toml` | Dependências, config do pytest |
| `ddr5_radar/config.py` | Lê variáveis de ambiente, uma fonte só de configuração |
| `ddr5_radar/contrato.py` | `OfertaCrua`, `Condicao`, `Formato`, `Adaptador` — o vocabulário que todo mundo compartilha |
| `ddr5_radar/coleta/adaptadores/kabum.py` | Só Kabum. Não sabe que os outros existem |
| `ddr5_radar/coleta/adaptadores/amazon.py` | Só Amazon |
| `ddr5_radar/coleta/adaptadores/mercadolivre.py` | Só Mercado Livre (API OAuth) |
| `ddr5_radar/coleta/adaptadores/pichau.py` | Só Pichau (Playwright) |
| `ddr5_radar/coleta/adaptadores/terabyte.py` | Só Terabyte (Playwright) |
| `ddr5_radar/coleta/adaptadores/__init__.py` | Registro `ADAPTADORES` |
| `ddr5_radar/coleta/navegador.py` | Contexto Playwright compartilhado pelos dois adaptadores que precisam de navegador |
| `ddr5_radar/coleta/executor.py` | Roda os adaptadores, isola falhas, mede tempo |
| `ddr5_radar/nucleo/normalizador.py` | Título livre → atributos → part number e chave canônica |
| `ddr5_radar/nucleo/modelos.py` | Tabelas SQLAlchemy (schema completo, incluindo o do Plano 2) |
| `ddr5_radar/nucleo/db.py` | Engine e sessão |
| `ddr5_radar/persistencia.py` | Grava uma rodada de coleta |
| `ddr5_radar/cli.py` | `python -m ddr5_radar.cli coletar` |
| `.github/workflows/coletar.yml` | Cron de 10 minutos |

Regra de dependência: `contrato.py` não importa nada do projeto — é o vocabulário, e todo mundo pode usá-lo. Fora isso, `coleta/` não importa de `nucleo/` nem de `persistencia.py`, e `nucleo/` não importa de `coleta/`. Quem costura é `cli.py`.

---

### Task 1: Esqueleto do projeto

**Files:**
- Create: `pyproject.toml`
- Create: `ddr5_radar/__init__.py`
- Create: `ddr5_radar/config.py`
- Create: `tests/__init__.py`
- Create: `tests/test_config.py`

**Interfaces:**
- Consumes: nada
- Produces: `ddr5_radar.config.Config` com os campos `database_url: str`, `telegram_token: str | None`, `telegram_chat_id: str | None`, `ml_client_id: str | None`, `ml_client_secret: str | None`; e `carregar_config() -> Config`

- [ ] **Step 1: Criar o `pyproject.toml`**

```toml
[project]
name = "ddr5-radar"
version = "0.1.0"
requires-python = ">=3.13,<3.14"
dependencies = [
    "httpx>=0.27",
    "selectolax>=0.3.21",
    "playwright>=1.47",
    "sqlalchemy>=2.0.30",
    "alembic>=1.13",
    "psycopg[binary]>=3.2",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.2",
    "pytest-asyncio>=0.23",
    "respx>=0.21",
]

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
markers = ["rede: bate na loja de verdade; nao roda por padrao"]
addopts = "-m 'not rede'"

[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"
```

- [ ] **Step 2: Escrever o teste que falha**

```python
# tests/test_config.py
import pytest
from ddr5_radar.config import carregar_config


def test_carrega_database_url_do_ambiente(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@host/db")
    config = carregar_config()
    assert config.database_url == "postgresql+psycopg://u:p@host/db"


def test_campos_opcionais_ficam_none_quando_ausentes(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@host/db")
    monkeypatch.delenv("TELEGRAM_TOKEN", raising=False)
    config = carregar_config()
    assert config.telegram_token is None


def test_explode_quando_falta_database_url(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        carregar_config()
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `python3.13 -m venv .venv && .venv/bin/pip install -e ".[dev]" && .venv/bin/pytest tests/test_config.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.config'`

- [ ] **Step 4: Implementar**

```python
# ddr5_radar/config.py
"""Fonte unica de configuracao. Ninguem le os.environ fora daqui."""
import os
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class Config:
    database_url: str
    telegram_token: str | None
    telegram_chat_id: str | None
    ml_client_id: str | None
    ml_client_secret: str | None


def carregar_config() -> Config:
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError(
            "DATABASE_URL nao esta definida. No GitHub Actions ela vem dos "
            "Secrets; localmente, exporte antes de rodar."
        )
    return Config(
        database_url=database_url,
        telegram_token=os.environ.get("TELEGRAM_TOKEN"),
        telegram_chat_id=os.environ.get("TELEGRAM_CHAT_ID"),
        ml_client_id=os.environ.get("ML_CLIENT_ID"),
        ml_client_secret=os.environ.get("ML_CLIENT_SECRET"),
    )
```

Criar também `ddr5_radar/__init__.py` e `tests/__init__.py` vazios.

- [ ] **Step 5: Rodar e ver passar**

Run: `.venv/bin/pytest -v`
Expected: PASS, 3 testes

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml ddr5_radar/ tests/
git commit -m "Esqueleto do projeto e carregamento de configuracao"
```

---

### Task 2: Contrato da coleta

**Files:**
- Create: `ddr5_radar/coleta/__init__.py`
- Create: `ddr5_radar/contrato.py`
- Create: `tests/test_contrato.py`

**Interfaces:**
- Consumes: nada
- Produces:
  - `Condicao` (StrEnum): `NOVO`, `USADO`, `RECONDICIONADO`, `DESCONHECIDO`
  - `Formato` (StrEnum): `DIMM`, `SODIMM`
  - `OfertaCrua` — dataclass congelada com: `loja: str`, `id_na_loja: str`, `titulo: str`, `preco_centavos: int`, `preco_original_centavos: int | None`, `em_estoque: bool`, `url: str`, `url_imagem: str | None`, `condicao: Condicao`, `vendedor: str | None`, `reputacao_vendedor: float | None`, `coletado_em: datetime`
  - `Adaptador` (Protocol): atributo `loja: str`, método `async def buscar(self, termo: str) -> list[OfertaCrua]`
  - `reais_para_centavos(valor: float | str) -> int`

- [ ] **Step 1: Escrever o teste que falha**

```python
# tests/test_contrato.py
from datetime import UTC, datetime

import pytest

from ddr5_radar.contrato import (
    Condicao,
    OfertaCrua,
    reais_para_centavos,
)


def test_oferta_e_imutavel():
    oferta = OfertaCrua(
        loja="kabum",
        id_na_loja="708332",
        titulo="Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5",
        preco_centavos=189999,
        preco_original_centavos=223528,
        em_estoque=True,
        url="https://www.kabum.com.br/produto/708332/x",
        url_imagem=None,
        condicao=Condicao.NOVO,
        vendedor="KaBuM!",
        reputacao_vendedor=None,
        coletado_em=datetime.now(UTC),
    )
    with pytest.raises(AttributeError):
        oferta.preco_centavos = 1


@pytest.mark.parametrize(
    ("entrada", "esperado"),
    [
        (1899.99, 189999),
        (1175.02, 117502),
        (5239.9, 523990),
        ("1.899,99", 189999),
        ("R$ 1.899,99", 189999),
        ("963,99", 96399),
        (0, 0),
    ],
)
def test_converte_reais_para_centavos(entrada, esperado):
    assert reais_para_centavos(entrada) == esperado
```

O caso `5239.9 -> 523990` é o que pega o bug clássico: `int(5239.9 * 100)` em ponto flutuante dá 523989.

- [ ] **Step 2: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/test_contrato.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.coleta'`

- [ ] **Step 3: Implementar**

```python
# ddr5_radar/contrato.py
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


def reais_para_centavos(valor: float | str) -> int:
    """Converte via Decimal: 5239.9 * 100 em float da 523989.99..."""
    if isinstance(valor, str):
        limpo = re.sub(r"[^\d,.-]", "", valor)
        if "," in limpo:  # formato brasileiro: 1.899,99
            limpo = limpo.replace(".", "").replace(",", ".")
        valor = limpo or "0"
    centavos = Decimal(str(valor)) * 100
    return int(centavos.quantize(Decimal("1"), rounding=ROUND_HALF_UP))
```

Criar `ddr5_radar/coleta/__init__.py` vazio (o pacote `coleta` ainda nao tem modulo proprio; ele chega na Task 7).

- [ ] **Step 4: Rodar e ver passar**

Run: `.venv/bin/pytest tests/test_contrato.py -v`
Expected: PASS, 8 testes

- [ ] **Step 5: Commit**

```bash
git add ddr5_radar/coleta/ tests/test_contrato.py
git commit -m "Contrato compartilhado dos adaptadores de coleta"
```

---

### Task 3: Normalizador — extração de atributos

**Files:**
- Create: `ddr5_radar/nucleo/__init__.py`
- Create: `ddr5_radar/nucleo/normalizador.py`
- Create: `tests/test_normalizador.py`

**Interfaces:**
- Consumes: `Formato` de `ddr5_radar.contrato`
- Produces:
  - `AtributosMemoria` — dataclass congelada: `marca: str | None`, `linha: str | None`, `capacidade_gb: int | None`, `modulos: int | None`, `velocidade_mts: int | None`, `latencia_cl: int | None`, `formato: Formato`, `rgb: bool`, `part_number: str | None`
  - `extrair_atributos(titulo: str) -> AtributosMemoria`

**Contexto para quem implementa:** os títulos abaixo são reais, coletados do Kabum e do Mercado Livre em 2026-08-24. Cada esquisitice deles existe de verdade: `MT/s` e `MHz` usados como sinônimo, `(2X16GB)` em maiúscula, part number em minúscula (`Kf556c40bb-8`), e "para Notebook" indicando SODIMM.

- [ ] **Step 1: Escrever o teste que falha**

```python
# tests/test_normalizador.py
import pytest

from ddr5_radar.contrato import Formato
from ddr5_radar.nucleo.normalizador import extrair_atributos

KABUM_SIMPLES = "Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5, CL36, DIMM, Preto, EXPO - KF556C36BBE-16"
KABUM_KIT = "Memória RAM Kingston Fury Beast Expo, 32GB (2X16GB), 6000MT/s, DDR5, DIMM, CL30, Branco - KF560C30BWEK2-32"
KABUM_MHZ = "Memória Gamer Kingston Fury Beast, 8GB, DDR5, 5600MHz, CL40 - Kf556c40bb-8"
KABUM_RGB = "Memória RAM Kingston Fury Beast RGB, 8GB, 5200MHz, DDR5, CL40, para Intel XMP, Preto - KF552C40BBA-8"
KABUM_NOTEBOOK = "Memória RAM para Notebook Corsair Vengeance, 8GB, 4800MHz, DDR5, CL40, Preto - CMSX8GX5M1A4800C40"
KABUM_CORSAIR_KIT = "Memória RAM Corsair Vengeance, 32GB (2x16GB), 6000MHz, DDR5, CL38, Intel XMP, Preto - CMK32GX5M2B6000C38"
ML_BAGUNCADO = "KIT MEMORIA RAM DDR5 32GB 6000 KINGSTON FURY BEAST RGB *ENVIO IMEDIATO*"


def test_extrai_capacidade_e_velocidade_do_titulo_simples():
    a = extrair_atributos(KABUM_SIMPLES)
    assert a.capacidade_gb == 16
    assert a.velocidade_mts == 5600
    assert a.latencia_cl == 36
    assert a.marca == "kingston"
    assert a.linha == "fury-beast"


def test_kit_usa_capacidade_total_e_conta_modulos():
    a = extrair_atributos(KABUM_KIT)
    assert a.capacidade_gb == 32   # o total, nao os 16 do modulo
    assert a.modulos == 2
    assert a.velocidade_mts == 6000


def test_mhz_e_mts_sao_a_mesma_grandeza():
    assert extrair_atributos(KABUM_MHZ).velocidade_mts == 5600


def test_rgb_e_detectado():
    assert extrair_atributos(KABUM_RGB).rgb is True
    assert extrair_atributos(KABUM_SIMPLES).rgb is False


def test_notebook_e_sodimm():
    assert extrair_atributos(KABUM_NOTEBOOK).formato is Formato.SODIMM
    assert extrair_atributos(KABUM_SIMPLES).formato is Formato.DIMM


def test_part_number_normalizado_em_maiuscula():
    assert extrair_atributos(KABUM_MHZ).part_number == "KF556C40BB-8"
    assert extrair_atributos(KABUM_SIMPLES).part_number == "KF556C36BBE-16"


def test_titulo_de_marketplace_sem_part_number():
    a = extrair_atributos(ML_BAGUNCADO)
    assert a.part_number is None
    assert a.marca == "kingston"
    assert a.linha == "fury-beast"
    assert a.capacidade_gb == 32
    assert a.velocidade_mts == 6000   # "DDR5 32GB 6000", sem unidade
    assert a.rgb is True


def test_campo_ausente_vira_none_e_nao_chute():
    a = extrair_atributos("Memória DDR5 sem mais nada")
    assert a.capacidade_gb is None
    assert a.velocidade_mts is None
    assert a.marca is None
    assert a.latencia_cl is None


def test_marca_da_corsair():
    a = extrair_atributos(KABUM_CORSAIR_KIT)
    assert a.marca == "corsair"
    assert a.linha == "vengeance"
    assert a.modulos == 2
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/test_normalizador.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.nucleo'`

- [ ] **Step 3: Implementar**

```python
# ddr5_radar/nucleo/normalizador.py
"""Titulo livre de loja -> atributos de memoria.

Regra de ouro: campo que nao foi encontrado vira None. Nunca chute.
Um chute errado aqui vira alerta falso la na frente.
"""
import re
import unicodedata
from dataclasses import dataclass

from ddr5_radar.contrato import Formato

MARCAS = {
    "kingston": ["kingston"],
    "corsair": ["corsair"],
    "adata": ["adata", "xpg"],
    "crucial": ["crucial", "micron"],
    "gskill": ["g.skill", "gskill", "g skill"],
    "teamgroup": ["teamgroup", "team group", "t-force", "tforce"],
    "patriot": ["patriot"],
    "netac": ["netac"],
    "lexar": ["lexar"],
    "samsung": ["samsung"],
    "sk-hynix": ["sk hynix", "hynix"],
    "husky": ["husky"],
    "rise-mode": ["rise mode", "rise-mode"],
    "pichau": ["pichau", "aegis"],
    "keepdata": ["keepdata"],
    "asgard": ["asgard"],
    "acer": ["acer", "predator"],
    "warrior": ["warrior", "multilaser"],
}

LINHAS = {
    "fury-beast": ["fury beast", "furybeast"],
    "fury-renegade": ["fury renegade", "renegade"],
    "vengeance": ["vengeance"],
    "dominator": ["dominator"],
    "ripjaws": ["ripjaws"],
    "trident-z": ["trident z", "trident-z", "tridentz"],
    "viper": ["viper"],
    "lancer": ["lancer"],
    "caster": ["caster"],
    "delta": ["delta"],
    "elite": ["elite"],
    "pro": ["pro "],
}


@dataclass(frozen=True, slots=True)
class AtributosMemoria:
    marca: str | None
    linha: str | None
    capacidade_gb: int | None
    modulos: int | None
    velocidade_mts: int | None
    latencia_cl: int | None
    formato: Formato
    rgb: bool
    part_number: str | None


def _sem_acento(texto: str) -> str:
    nfkd = unicodedata.normalize("NFKD", texto)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def _achar(mapa: dict[str, list[str]], texto: str) -> str | None:
    for canonico, apelidos in mapa.items():
        if any(apelido in texto for apelido in apelidos):
            return canonico
    return None


def _capacidade_e_modulos(texto: str) -> tuple[int | None, int | None]:
    # "32GB (2x16GB)" -> total 32, modulos 2. O total declarado manda.
    kit = re.search(r"(\d{1,3})\s*gb\s*\(\s*(\d)\s*x\s*(\d{1,3})\s*gb?\s*\)", texto)
    if kit:
        return int(kit.group(1)), int(kit.group(2))
    # "(2x16GB)" ou "2x16GB" sem total: multiplica
    solto = re.search(r"\(?\s*(\d)\s*x\s*(\d{1,3})\s*gb", texto)
    if solto:
        return int(solto.group(1)) * int(solto.group(2)), int(solto.group(1))
    simples = re.search(r"(\d{1,3})\s*gb", texto)
    if simples:
        # modulos fica None: "32GB" pode ser 1x32 ou kit nao declarado.
        return int(simples.group(1)), None
    return None, None


def _velocidade(texto: str) -> int | None:
    # MT/s e MHz sao a mesma grandeza nos catalogos das lojas.
    com_unidade = re.search(r"(\d{4,5})\s*(?:mt/s|mts|mhz)", texto)
    if com_unidade:
        return int(com_unidade.group(1))
    # marketplace escreve "DDR5 32GB 6000" sem unidade nenhuma
    solto = re.search(r"ddr5[^\d]{0,12}?(\d{4,5})(?!\s*gb)", texto)
    if solto:
        return int(solto.group(1))
    depois_do_gb = re.search(r"\d{1,3}\s*gb[^\d]{1,12}?(\d{4,5})(?!\s*gb)", texto)
    return int(depois_do_gb.group(1)) if depois_do_gb else None


def _part_number(titulo: str) -> str | None:
    """Codigo do fabricante, quase sempre no fim depois de um traco."""
    fim = re.search(r"[-–—]\s*([A-Za-z0-9][A-Za-z0-9./-]{5,})\s*$", titulo.strip())
    if not fim:
        return None
    candidato = fim.group(1)
    tem_letras = len(re.findall(r"[A-Za-z]", candidato)) >= 2
    tem_digitos = len(re.findall(r"\d", candidato)) >= 2
    return candidato.upper() if tem_letras and tem_digitos else None


def extrair_atributos(titulo: str) -> AtributosMemoria:
    texto = _sem_acento(titulo).lower()
    capacidade, modulos = _capacidade_e_modulos(texto)
    latencia = re.search(r"\bcl\s*(\d{2})\b", texto)
    e_notebook = any(t in texto for t in ("notebook", "sodimm", "so-dimm", "so dimm"))
    return AtributosMemoria(
        marca=_achar(MARCAS, texto),
        linha=_achar(LINHAS, texto),
        capacidade_gb=capacidade,
        modulos=modulos,
        velocidade_mts=_velocidade(texto),
        latencia_cl=int(latencia.group(1)) if latencia else None,
        formato=Formato.SODIMM if e_notebook else Formato.DIMM,
        rgb=bool(re.search(r"\brgb\b", texto)),
        part_number=_part_number(titulo),
    )
```

Criar `ddr5_radar/nucleo/__init__.py` vazio.

- [ ] **Step 4: Rodar e ver passar**

Run: `.venv/bin/pytest tests/test_normalizador.py -v`
Expected: PASS, 9 testes

- [ ] **Step 5: Commit**

```bash
git add ddr5_radar/nucleo/ tests/test_normalizador.py
git commit -m "Extracao de atributos de memoria a partir do titulo"
```

---

### Task 4: Normalizador — identidade do produto

**Files:**
- Modify: `ddr5_radar/nucleo/normalizador.py`
- Modify: `tests/test_normalizador.py`

**Interfaces:**
- Consumes: `AtributosMemoria`, `extrair_atributos` da Task 3
- Produces:
  - `eh_ddr5(titulo: str, atributos: AtributosMemoria) -> bool`
  - `eh_memoria(titulo: str) -> bool`
  - `chave_canonica(atributos: AtributosMemoria) -> str | None`

**Decisão de design que quem implementa precisa entender:** a chave canônica **não inclui a latência CL**, porque ela falta em muitos títulos de marketplace e sua ausência quebraria matches legítimos. Inclui `linha`, e por isso **exige** que a linha tenha sido reconhecida — sem ela, retorna `None`, e o produto passa a depender do part number para ser identificado. Preferimos identificar menos a identificar errado: um match falso vira alerta falso (spec §7).

Part number e chave canônica são **guardados os dois** na tabela. Quem agrupa as ofertas é o motor de detecção, no Plano 2, usando o part number quando existe e a chave como reserva.

- [ ] **Step 1: Escrever o teste que falha**

```python
# acrescentar em tests/test_normalizador.py
from ddr5_radar.nucleo.normalizador import chave_canonica, eh_ddr5, eh_memoria

DDR4 = "Memória RAM Kingston Fury Beast, 16GB, 3200MHz, DDR4, CL16 - KF432C16BB1-16"


PC_GAMER = "PC Gamer Plataforma AMD Ryzen 7000 DDR5 AM5 (FULL CUSTOM)"
PLACA_MAE = "Placa-mãe ASUS TUF Gaming B650M-E WiFi DDR5, Socket AM5, mATX"


def test_pc_montado_nao_e_memoria():
    assert eh_memoria(PC_GAMER) is False


def test_placa_mae_nao_e_memoria():
    assert eh_memoria(PLACA_MAE) is False


def test_pente_de_memoria_e_memoria():
    assert eh_memoria(KABUM_SIMPLES) is True
    assert eh_memoria(ML_BAGUNCADO) is True


def test_ddr4_nao_passa():
    a = extrair_atributos(DDR4)
    assert eh_ddr5(DDR4, a) is False


def test_ddr5_declarado_passa():
    a = extrair_atributos(KABUM_SIMPLES)
    assert eh_ddr5(KABUM_SIMPLES, a) is True


def test_sem_rotulo_mas_rapido_demais_para_ddr4_passa():
    titulo = "Memoria 16GB 5600MHz Kingston Fury Beast"
    assert eh_ddr5(titulo, extrair_atributos(titulo)) is True


def test_chave_ignora_latencia_para_nao_perder_match():
    com_cl = extrair_atributos(
        "Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5, CL36 - KF556C36BBE-16"
    )
    sem_cl = extrair_atributos("MEMORIA KINGSTON FURY BEAST 16GB DDR5 5600")
    assert chave_canonica(com_cl) == chave_canonica(sem_cl)


def test_notebook_e_desktop_nao_compartilham_chave():
    desktop = extrair_atributos("Memória Corsair Vengeance, 8GB, 4800MHz, DDR5")
    notebook = extrair_atributos("Memória para Notebook Corsair Vengeance, 8GB, 4800MHz, DDR5")
    assert chave_canonica(desktop) != chave_canonica(notebook)


def test_rgb_muda_a_chave():
    com = extrair_atributos("Memória Kingston Fury Beast RGB, 16GB, 5600MHz, DDR5")
    sem = extrair_atributos("Memória Kingston Fury Beast, 16GB, 5600MHz, DDR5")
    assert chave_canonica(com) != chave_canonica(sem)


def test_sem_linha_reconhecida_nao_gera_chave():
    a = extrair_atributos("Memoria DDR5 16GB 5600MHz marca desconhecida")
    assert chave_canonica(a) is None


def test_chave_e_estavel_e_legivel():
    a = extrair_atributos(KABUM_KIT)
    assert chave_canonica(a) == "kingston|fury-beast|32|2|6000|dimm|sem-rgb"
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/test_normalizador.py -v`
Expected: FAIL — `ImportError: cannot import name 'chave_canonica'`

- [ ] **Step 3: Implementar**

```python
# acrescentar ao fim de ddr5_radar/nucleo/normalizador.py

VELOCIDADE_MINIMA_DDR5 = 4800  # a DDR5 mais lenta de fabrica


def eh_ddr5(titulo: str, atributos: AtributosMemoria) -> bool:
    texto = _sem_acento(titulo).lower()
    if re.search(r"\bddr[234]\b", texto):
        return False
    if "ddr5" in texto:
        return True
    velocidade = atributos.velocidade_mts
    return velocidade is not None and velocidade >= VELOCIDADE_MINIMA_DDR5


NAO_E_MEMORIA = (
    "pc gamer", "computador", "placa-mae", "placa mae", "placa m e",
    "processador", "notebook gamer", "kit upgrade", "kit de upgrade",
    "workstation", "servidor", "all in one",
)


def eh_memoria(titulo: str) -> bool:
    """Nem tudo que diz DDR5 e memoria.

    A busca da Terabyte devolve "PC Gamer Plataforma AMD Ryzen 7000 DDR5" e
    "Placa-mae ASUS TUF B650M-E DDR5" (coletado em 2026-08-24). Um PC de 32GB
    entraria como pente de 32GB e envenenaria a mediana.
    """
    texto = _sem_acento(titulo).lower()
    return not any(termo in texto for termo in NAO_E_MEMORIA)


def chave_canonica(atributos: AtributosMemoria) -> str | None:
    """Identidade de reserva, para quando nao ha part number.

    Sem latencia de proposito: ela falta em muito titulo de marketplace e
    a ausencia quebraria matches legitimos. Exige linha reconhecida --
    identificar menos e melhor que identificar errado.
    """
    if not (
        atributos.marca
        and atributos.linha
        and atributos.capacidade_gb
        and atributos.velocidade_mts
    ):
        return None
    return "|".join(
        [
            atributos.marca,
            atributos.linha,
            str(atributos.capacidade_gb),
            str(atributos.modulos) if atributos.modulos else "?",
            str(atributos.velocidade_mts),
            atributos.formato.value,
            "rgb" if atributos.rgb else "sem-rgb",
        ]
    )
```

- [ ] **Step 4: Rodar e ver passar**

Run: `.venv/bin/pytest tests/test_normalizador.py -v`
Expected: PASS, 20 testes

- [ ] **Step 5: Commit**

```bash
git add ddr5_radar/nucleo/normalizador.py tests/test_normalizador.py
git commit -m "Identidade do produto: filtro DDR5 e chave canonica"
```

---

### Task 5: Schema do banco

**Files:**
- Create: `ddr5_radar/nucleo/modelos.py`
- Create: `ddr5_radar/nucleo/db.py`
- Create: `alembic.ini`, `alembic/env.py`, `alembic/versions/0001_inicial.py`
- Create: `tests/test_modelos.py`

**Interfaces:**
- Consumes: `carregar_config` (Task 1), `Condicao`/`Formato` (Task 2)
- Produces:
  - `Base`, e as tabelas `Oferta`, `PrecoObservado`, `Rodada`, `SaudeAdaptador`, `Alerta`, `Configuracao`
  - `criar_sessao() -> sessionmaker[Session]`

**O schema nasce completo** (spec §15): `Alerta` e `Configuracao` só são usadas no Plano 2, mas entram agora para não haver segunda migration mexendo em tabela com dado dentro.

- [ ] **Step 1: Escrever o teste que falha**

```python
# tests/test_modelos.py
from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ddr5_radar.contrato import Condicao, Formato
from ddr5_radar.nucleo.modelos import Base, Oferta, PrecoObservado, Rodada


@pytest.fixture
def sessao():
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        yield s


def _oferta(**extra) -> Oferta:
    campos = dict(
        loja="kabum",
        id_na_loja="708332",
        titulo="Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5",
        url="https://www.kabum.com.br/produto/708332/x",
        part_number="KF556C36BBE-16",
        chave_canonica="kingston|fury-beast|16|?|5600|dimm|sem-rgb",
        marca="kingston",
        capacidade_gb=16,
        velocidade_mts=5600,
        formato=Formato.DIMM.value,
        condicao=Condicao.NOVO.value,
        primeira_vez_em=datetime.now(UTC),
        ultima_vez_em=datetime.now(UTC),
    )
    campos.update(extra)
    return Oferta(**campos)


def test_a_mesma_oferta_nao_entra_duas_vezes(sessao):
    sessao.add(_oferta())
    sessao.commit()
    sessao.add(_oferta())
    with pytest.raises(IntegrityError):
        sessao.commit()


def test_mesmo_id_em_lojas_diferentes_convive(sessao):
    sessao.add(_oferta(loja="kabum"))
    sessao.add(_oferta(loja="pichau"))
    sessao.commit()
    assert len(sessao.scalars(select(Oferta)).all()) == 2


def test_preco_pertence_a_uma_oferta(sessao):
    oferta = _oferta()
    rodada = Rodada(iniciada_em=datetime.now(UTC))
    sessao.add_all([oferta, rodada])
    sessao.flush()
    sessao.add(
        PrecoObservado(
            oferta_id=oferta.id,
            rodada_id=rodada.id,
            preco_centavos=189999,
            em_estoque=True,
            centavos_por_gb=11874,
            observado_em=datetime.now(UTC),
        )
    )
    sessao.commit()
    assert oferta.precos[0].preco_centavos == 189999
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/test_modelos.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.nucleo.modelos'`

- [ ] **Step 3: Implementar os modelos**

```python
# ddr5_radar/nucleo/modelos.py
"""Schema completo, incluindo as tabelas que so o Plano 2 usa.

Dinheiro e sempre inteiro em centavos. Datas sempre com fuso.
"""
from datetime import datetime

from sqlalchemy import (
    Boolean, DateTime, Float, ForeignKey, Index, Integer, String, Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

from ddr5_radar.contrato import Condicao, Formato


class Base(DeclarativeBase):
    pass


class Oferta(Base):
    """Um anuncio numa loja. Vive enquanto a loja o mantiver no ar."""
    __tablename__ = "ofertas"
    __table_args__ = (
        UniqueConstraint("loja", "id_na_loja", name="uq_oferta_loja_id"),
        Index("ix_oferta_part_number", "part_number"),
        Index("ix_oferta_chave", "chave_canonica"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    loja: Mapped[str] = mapped_column(String(32))
    id_na_loja: Mapped[str] = mapped_column(String(64))
    titulo: Mapped[str] = mapped_column(Text)
    url: Mapped[str] = mapped_column(Text)
    url_imagem: Mapped[str | None] = mapped_column(Text, default=None)

    # identidade do produto (spec §7)
    part_number: Mapped[str | None] = mapped_column(String(64), default=None)
    chave_canonica: Mapped[str | None] = mapped_column(String(128), default=None)
    marca: Mapped[str | None] = mapped_column(String(32), default=None)
    linha: Mapped[str | None] = mapped_column(String(32), default=None)
    capacidade_gb: Mapped[int | None] = mapped_column(Integer, default=None)
    modulos: Mapped[int | None] = mapped_column(Integer, default=None)
    velocidade_mts: Mapped[int | None] = mapped_column(Integer, default=None)
    latencia_cl: Mapped[int | None] = mapped_column(Integer, default=None)
    # str e nao Mapped[Formato]: a coluna e String, e o SQLAlchemy devolve str
    # na leitura. Declarar o enum aqui seria mentir sobre o tipo que volta.
    formato: Mapped[str] = mapped_column(String(16), default=Formato.DIMM.value)
    rgb: Mapped[bool] = mapped_column(Boolean, default=False)

    condicao: Mapped[str] = mapped_column(String(16), default=Condicao.DESCONHECIDO.value)
    vendedor: Mapped[str | None] = mapped_column(String(128), default=None)
    reputacao_vendedor: Mapped[float | None] = mapped_column(Float, default=None)

    primeira_vez_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ultima_vez_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    precos: Mapped[list["PrecoObservado"]] = relationship(
        back_populates="oferta", order_by="PrecoObservado.observado_em"
    )


class PrecoObservado(Base):
    """So grava quando o preco muda -- 144 coletas por dia sem isso viram lixo."""
    __tablename__ = "precos"
    __table_args__ = (Index("ix_preco_oferta_data", "oferta_id", "observado_em"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    oferta_id: Mapped[int] = mapped_column(ForeignKey("ofertas.id"))
    rodada_id: Mapped[int] = mapped_column(ForeignKey("rodadas.id"))
    preco_centavos: Mapped[int] = mapped_column(Integer)
    preco_original_centavos: Mapped[int | None] = mapped_column(Integer, default=None)
    em_estoque: Mapped[bool] = mapped_column(Boolean, default=True)
    centavos_por_gb: Mapped[int | None] = mapped_column(Integer, default=None)
    observado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    oferta: Mapped[Oferta] = relationship(back_populates="precos")


class Rodada(Base):
    __tablename__ = "rodadas"

    id: Mapped[int] = mapped_column(primary_key=True)
    iniciada_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    terminada_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    ofertas_vistas: Mapped[int] = mapped_column(Integer, default=0)
    precos_gravados: Mapped[int] = mapped_column(Integer, default=0)


class SaudeAdaptador(Base):
    """Quem quebrou, quando, e por que. E o que o painel mostra em 'Pichau: sem dados ha 3h'."""
    __tablename__ = "saude_adaptadores"

    id: Mapped[int] = mapped_column(primary_key=True)
    rodada_id: Mapped[int] = mapped_column(ForeignKey("rodadas.id"))
    loja: Mapped[str] = mapped_column(String(32))
    sucesso: Mapped[bool] = mapped_column(Boolean)
    qtd_ofertas: Mapped[int] = mapped_column(Integer, default=0)
    erro: Mapped[str | None] = mapped_column(Text, default=None)
    duracao_ms: Mapped[int] = mapped_column(Integer, default=0)


class Alerta(Base):
    """Usada so no Plano 2. Existe agora para nao migrar tabela com dado dentro."""
    __tablename__ = "alertas"

    id: Mapped[int] = mapped_column(primary_key=True)
    oferta_id: Mapped[int] = mapped_column(ForeignKey("ofertas.id"))
    selo: Mapped[str] = mapped_column(String(8))   # "bug" | "promo"
    sinal: Mapped[str] = mapped_column(String(24))  # "desvio_lojas" | "queda_historico" | "curva_mercado"
    preco_centavos: Mapped[int] = mapped_column(Integer)
    referencia_centavos: Mapped[int | None] = mapped_column(Integer, default=None)
    desvio_percentual: Mapped[float | None] = mapped_column(Float, default=None)
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    notificado_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    dispensado_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)


class Configuracao(Base):
    """Linha unica. Usada so no Plano 2; valores iniciais vem da spec §8."""
    __tablename__ = "configuracao"

    id: Mapped[int] = mapped_column(primary_key=True, default=1)
    limiar_bug_mediana: Mapped[float] = mapped_column(Float, default=0.55)
    limiar_promo_mediana: Mapped[float] = mapped_column(Float, default=0.80)
    limiar_bug_queda: Mapped[float] = mapped_column(Float, default=0.40)
    limiar_promo_queda: Mapped[float] = mapped_column(Float, default=0.20)
    percentil_curva: Mapped[int] = mapped_column(Integer, default=5)
    min_lojas_mediana: Mapped[int] = mapped_column(Integer, default=3)
    silencio_inicio_hora: Mapped[int] = mapped_column(Integer, default=23)
    silencio_fim_hora: Mapped[int] = mapped_column(Integer, default=7)
    lojas_desligadas: Mapped[str] = mapped_column(Text, default="")
```

```python
# ddr5_radar/nucleo/db.py
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from ddr5_radar.config import carregar_config


def criar_sessao() -> sessionmaker[Session]:
    config = carregar_config()
    engine = create_engine(config.database_url, pool_pre_ping=True)
    return sessionmaker(engine, expire_on_commit=False)
```

- [ ] **Step 4: Rodar e ver passar**

Run: `.venv/bin/pytest tests/test_modelos.py -v`
Expected: PASS, 3 testes

- [ ] **Step 5: Gerar a migration**

```bash
.venv/bin/alembic init alembic
```

Em `alembic/env.py`, trocar o bloco de configuração por:

```python
import os
from ddr5_radar.nucleo.modelos import Base
target_metadata = Base.metadata
config.set_main_option("sqlalchemy.url", os.environ["DATABASE_URL"])
```

Depois:

```bash
export DATABASE_URL="postgresql+psycopg://postgres:SENHA@db.PROJETO.supabase.co:5432/postgres"
.venv/bin/alembic revision --autogenerate -m "inicial"
.venv/bin/alembic upgrade head
```

Renomear o arquivo gerado para `alembic/versions/0001_inicial.py`.

**Antes deste passo é preciso criar o projeto `ddr5-radar` no Supabase** e pegar a connection string. Usar a porta **5432 (conexão direta)** aqui, porque o Alembic precisa de sessão real; a porta 6543 (pooler) é só para o painel do Plano 2 (spec §4).

- [ ] **Step 6: Commit**

```bash
git add ddr5_radar/nucleo/ alembic/ alembic.ini tests/test_modelos.py
git commit -m "Schema completo do banco e migration inicial"
```

---

### Task 6: Persistência de uma rodada

**Files:**
- Create: `ddr5_radar/persistencia.py`
- Create: `tests/test_persistencia.py`

**Interfaces:**
- Consumes: `OfertaCrua` (Task 2), `extrair_atributos`/`eh_ddr5`/`chave_canonica` (Tasks 3-4), modelos (Task 5)
- Produces:
  - `ResumoGravacao` — dataclass: `ofertas_novas: int`, `ofertas_atualizadas: int`, `precos_gravados: int`, `descartadas: int`
  - `iniciar_rodada(sessao) -> Rodada`
  - `gravar_ofertas(sessao, rodada, ofertas: list[OfertaCrua]) -> ResumoGravacao`
  - `registrar_saude(sessao, rodada, loja: str, sucesso: bool, qtd: int, erro: str | None, duracao_ms: int) -> None`
  - `finalizar_rodada(sessao, rodada, resumo: ResumoGravacao) -> None`

**Regra central:** preço só vira linha nova quando **muda**. São 144 coletas por dia; gravar tudo encheria o banco de repetição e não acrescentaria informação. Quando o preço não mudou, só o `ultima_vez_em` da oferta é atualizado.

- [ ] **Step 1: Escrever o teste que falha**

```python
# tests/test_persistencia.py
from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from ddr5_radar.contrato import Condicao, OfertaCrua
from ddr5_radar.nucleo.modelos import Base, Oferta, PrecoObservado
from ddr5_radar.persistencia import (
    finalizar_rodada, gravar_ofertas, iniciar_rodada, registrar_saude,
)


@pytest.fixture
def sessao():
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        yield s


def _crua(preco_centavos: int = 189999, **extra) -> OfertaCrua:
    campos = dict(
        loja="kabum",
        id_na_loja="708332",
        titulo="Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5, CL36 - KF556C36BBE-16",
        preco_centavos=preco_centavos,
        preco_original_centavos=223528,
        em_estoque=True,
        url="https://www.kabum.com.br/produto/708332/x",
        url_imagem=None,
        condicao=Condicao.NOVO,
        vendedor="KaBuM!",
        reputacao_vendedor=None,
        coletado_em=datetime.now(UTC),
    )
    campos.update(extra)
    return OfertaCrua(**campos)


def test_grava_oferta_nova_com_atributos_extraidos(sessao):
    rodada = iniciar_rodada(sessao)
    resumo = gravar_ofertas(sessao, rodada, [_crua()])
    assert resumo.ofertas_novas == 1
    assert resumo.precos_gravados == 1

    oferta = sessao.scalars(select(Oferta)).one()
    assert oferta.part_number == "KF556C36BBE-16"
    assert oferta.capacidade_gb == 16
    assert oferta.velocidade_mts == 5600


def test_calcula_centavos_por_gb(sessao):
    rodada = iniciar_rodada(sessao)
    gravar_ofertas(sessao, rodada, [_crua(preco_centavos=189999)])
    preco = sessao.scalars(select(PrecoObservado)).one()
    assert preco.centavos_por_gb == 189999 // 16


def test_preco_repetido_nao_vira_linha_nova(sessao):
    rodada = iniciar_rodada(sessao)
    gravar_ofertas(sessao, rodada, [_crua(preco_centavos=189999)])
    segunda = iniciar_rodada(sessao)
    resumo = gravar_ofertas(sessao, segunda, [_crua(preco_centavos=189999)])

    assert resumo.ofertas_novas == 0
    assert resumo.ofertas_atualizadas == 1
    assert resumo.precos_gravados == 0
    assert len(sessao.scalars(select(PrecoObservado)).all()) == 1


def test_preco_diferente_vira_linha_nova(sessao):
    rodada = iniciar_rodada(sessao)
    gravar_ofertas(sessao, rodada, [_crua(preco_centavos=189999)])
    segunda = iniciar_rodada(sessao)
    resumo = gravar_ofertas(sessao, segunda, [_crua(preco_centavos=99999)])

    assert resumo.precos_gravados == 1
    assert len(sessao.scalars(select(PrecoObservado)).all()) == 2


def test_pc_gamer_com_ddr5_e_descartado(sessao):
    rodada = iniciar_rodada(sessao)
    pc = _crua(titulo="PC Gamer Plataforma AMD Ryzen 7000 DDR5 AM5 32GB (FULL CUSTOM)")
    resumo = gravar_ofertas(sessao, rodada, [pc])

    assert resumo.descartadas == 1
    assert sessao.scalars(select(Oferta)).all() == []


def test_ddr4_e_descartada_na_entrada(sessao):
    rodada = iniciar_rodada(sessao)
    ddr4 = _crua(titulo="Memória Kingston Fury Beast, 16GB, 3200MHz, DDR4, CL16")
    resumo = gravar_ofertas(sessao, rodada, [ddr4])

    assert resumo.descartadas == 1
    assert resumo.ofertas_novas == 0
    assert sessao.scalars(select(Oferta)).all() == []


def test_saida_de_estoque_vira_linha_nova(sessao):
    rodada = iniciar_rodada(sessao)
    gravar_ofertas(sessao, rodada, [_crua(em_estoque=True)])
    segunda = iniciar_rodada(sessao)
    resumo = gravar_ofertas(sessao, segunda, [_crua(em_estoque=False)])
    assert resumo.precos_gravados == 1


def test_registra_saude_e_fecha_rodada(sessao):
    rodada = iniciar_rodada(sessao)
    registrar_saude(sessao, rodada, "pichau", sucesso=False, qtd=0,
                    erro="403 anti-bot", duracao_ms=1200)
    resumo = gravar_ofertas(sessao, rodada, [_crua()])
    finalizar_rodada(sessao, rodada, resumo)

    assert rodada.terminada_em is not None
    assert rodada.precos_gravados == 1
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/test_persistencia.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.persistencia'`

- [ ] **Step 3: Implementar**

```python
# ddr5_radar/persistencia.py
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
from ddr5_radar.nucleo.normalizador import chave_canonica, eh_ddr5, eh_memoria, extrair_atributos


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
```

- [ ] **Step 4: Rodar e ver passar**

Run: `.venv/bin/pytest tests/test_persistencia.py -v`
Expected: PASS, 8 testes

- [ ] **Step 5: Commit**

```bash
git add ddr5_radar/persistencia.py tests/test_persistencia.py
git commit -m "Persistencia de rodada com historico so nas mudancas de preco"
```

---

### Task 7: Adaptador Kabum

**Files:**
- Modify: `ddr5_radar/contrato.py` (acrescentar as exceções)
- Create: `ddr5_radar/coleta/adaptadores/__init__.py`
- Create: `ddr5_radar/coleta/adaptadores/kabum.py`
- Create: `scripts/capturar_fixture.py`
- Create: `tests/fixtures/kabum_busca_ddr5.html` (gerado pelo script)
- Create: `tests/adaptadores/__init__.py`, `tests/adaptadores/test_kabum.py`

**Interfaces:**
- Consumes: `OfertaCrua`, `Condicao`, `reais_para_centavos` (Task 2)
- Produces:
  - `ColetaBloqueada(Exception)` e `AdaptadorNaoConfigurado(Exception)` em `contrato.py`
  - `AdaptadorKabum` com `loja = "kabum"` e `async def buscar(termo) -> list[OfertaCrua]`
  - `extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]` — a função pura, testável sem rede

**Estrutura confirmada em 2026-08-24:** o HTML da busca traz um `<script id="__NEXT_DATA__" type="application/json">` cujo caminho `props.pageProps.data.catalogServer.data` é a lista de produtos. Cada item tem `code`, `name`, `friendlyName`, `price`, `priceWithDiscount`, `available`, `quantity`, `image`, `sellerName`, `flags.isMarketplace`, `flags.isOpenbox`.

- [ ] **Step 1: Escrever o script de captura de fixture**

```python
# scripts/capturar_fixture.py
"""Baixa a pagina de busca de uma loja e salva em tests/fixtures/.

Uso: python scripts/capturar_fixture.py kabum
As lojas com anti-bot (pichau, terabyte) sao capturadas via Playwright.
"""
import asyncio
import sys
from pathlib import Path

import httpx

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)
DESTINO = Path(__file__).parent.parent / "tests" / "fixtures"

URLS_HTTP = {
    "kabum": "https://www.kabum.com.br/busca/ddr5",
    "amazon": "https://www.amazon.com.br/s?k=memoria+ddr5",
}
URLS_NAVEGADOR = {
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
```

Rodar: `.venv/bin/python scripts/capturar_fixture.py kabum`

- [ ] **Step 2: Escrever o teste que falha**

```python
# tests/adaptadores/test_kabum.py
from datetime import UTC, datetime
from pathlib import Path

import pytest

from ddr5_radar.coleta.adaptadores.kabum import extrair_do_html
from ddr5_radar.contrato import ColetaBloqueada, Condicao

FIXTURE = Path(__file__).parent.parent / "fixtures" / "kabum_busca_ddr5.html"


@pytest.fixture
def ofertas():
    html = FIXTURE.read_text(encoding="utf-8")
    return extrair_do_html(html, datetime.now(UTC))


def test_encontra_produtos(ofertas):
    assert len(ofertas) >= 20


def test_preco_vem_em_centavos_inteiros(ofertas):
    for oferta in ofertas:
        assert isinstance(oferta.preco_centavos, int)
        assert oferta.preco_centavos > 0


def test_url_do_produto_e_absoluta(ofertas):
    for oferta in ofertas:
        assert oferta.url.startswith("https://www.kabum.com.br/produto/")


def test_id_na_loja_e_o_codigo_kabum(ofertas):
    for oferta in ofertas:
        assert oferta.id_na_loja.isdigit()


def test_todas_marcadas_como_kabum(ofertas):
    assert {o.loja for o in ofertas} == {"kabum"}


def test_condicao_padrao_e_novo(ofertas):
    assert all(o.condicao is Condicao.NOVO for o in ofertas if "openbox" not in o.titulo.lower())


def test_html_sem_next_data_denuncia_bloqueio():
    with pytest.raises(ColetaBloqueada, match="__NEXT_DATA__"):
        extrair_do_html("<html><body>Acesso negado</body></html>", datetime.now(UTC))
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/adaptadores/test_kabum.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.coleta.adaptadores'`

- [ ] **Step 4: Acrescentar as exceções ao contrato**

```python
# acrescentar ao fim de ddr5_radar/contrato.py

class ColetaBloqueada(Exception):
    """A loja respondeu, mas com bloqueio (403, captcha, pagina de manutencao).

    Diferente de um erro de programacao: o executor registra e segue.
    """


class AdaptadorNaoConfigurado(Exception):
    """Falta credencial para essa loja. Nao e falha, e configuracao ausente."""
```

- [ ] **Step 5: Implementar o adaptador**

```python
# ddr5_radar/coleta/adaptadores/kabum.py
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
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
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
            "Kabum nao devolveu __NEXT_DATA__ — provavelmente bloqueio ou mudanca de layout"
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
```

```python
# ddr5_radar/coleta/adaptadores/__init__.py
"""Registro dos adaptadores. Acrescentar loja aqui e a unica costura necessaria."""
from ddr5_radar.coleta.adaptadores.kabum import AdaptadorKabum

ADAPTADORES = {
    "kabum": AdaptadorKabum(),
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `.venv/bin/pytest tests/adaptadores/test_kabum.py -v`
Expected: PASS, 7 testes

- [ ] **Step 7: Commit**

```bash
git add ddr5_radar/coleta/ scripts/ tests/adaptadores/ tests/fixtures/
git commit -m "Adaptador do Kabum lendo o JSON do __NEXT_DATA__"
```

---

### Task 8: Adaptador Amazon BR

**Files:**
- Create: `ddr5_radar/coleta/adaptadores/amazon.py`
- Create: `tests/fixtures/amazon_busca_ddr5.html` (gerado pelo script da Task 7)
- Create: `tests/adaptadores/test_amazon.py`
- Modify: `ddr5_radar/coleta/adaptadores/__init__.py`

**Interfaces:**
- Consumes: `OfertaCrua`, `Condicao`, `ColetaBloqueada`, `reais_para_centavos` (Tasks 2 e 7)
- Produces: `AdaptadorAmazon` (`loja = "amazon"`) e `extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]`

**O que muda em relação ao Kabum:** não há JSON embutido — é HTML puro, lido com selectolax. E a Amazon serve captcha quando o ritmo aperta; isso precisa virar `ColetaBloqueada` e não um resultado vazio silencioso, senão o painel mostra "0 ofertas" como se fosse normal.

- [ ] **Step 1: Capturar a fixture**

Run: `.venv/bin/python scripts/capturar_fixture.py amazon`
Expected: arquivo `tests/fixtures/amazon_busca_ddr5.html` com mais de 100 KB

- [ ] **Step 2: Escrever o teste que falha**

```python
# tests/adaptadores/test_amazon.py
from datetime import UTC, datetime
from pathlib import Path

import pytest

from ddr5_radar.coleta.adaptadores.amazon import extrair_do_html
from ddr5_radar.contrato import ColetaBloqueada

FIXTURE = Path(__file__).parent.parent / "fixtures" / "amazon_busca_ddr5.html"


@pytest.fixture
def ofertas():
    return extrair_do_html(FIXTURE.read_text(encoding="utf-8"), datetime.now(UTC))


def test_encontra_produtos(ofertas):
    assert len(ofertas) >= 10


def test_asin_tem_dez_caracteres(ofertas):
    for oferta in ofertas:
        assert len(oferta.id_na_loja) == 10


def test_preco_brasileiro_vira_centavos(ofertas):
    for oferta in ofertas:
        assert isinstance(oferta.preco_centavos, int)
        assert oferta.preco_centavos > 1000  # nenhuma DDR5 custa menos de R$ 10


def test_url_absoluta_de_produto(ofertas):
    for oferta in ofertas:
        assert oferta.url.startswith("https://www.amazon.com.br/")
        assert "/dp/" in oferta.url


def test_titulo_nao_vem_vazio(ofertas):
    assert all(len(o.titulo.strip()) > 10 for o in ofertas)


def test_captcha_vira_bloqueio_e_nao_lista_vazia():
    html = '<html><form action="/errors/validateCaptcha">...</form></html>'
    with pytest.raises(ColetaBloqueada, match="captcha"):
        extrair_do_html(html, datetime.now(UTC))


def test_pagina_sem_resultado_nem_captcha_e_lista_vazia():
    html = "<html><body><div>Nenhum resultado</div></body></html>"
    assert extrair_do_html(html, datetime.now(UTC)) == []
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/adaptadores/test_amazon.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.coleta.adaptadores.amazon'`

- [ ] **Step 4: Implementar**

```python
# ddr5_radar/coleta/adaptadores/amazon.py
"""Amazon BR: HTML puro da busca.

A Amazon serve captcha quando o ritmo aperta. Isso vira ColetaBloqueada --
devolver lista vazia faria o painel mostrar "0 ofertas" como se fosse
normal, escondendo o problema.
"""
import asyncio
from datetime import UTC, datetime
from urllib.parse import urljoin

import httpx
from selectolax.parser import HTMLParser

from ddr5_radar.contrato import (
    ColetaBloqueada, Condicao, OfertaCrua, reais_para_centavos,
)

BASE = "https://www.amazon.com.br"
UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)
PAGINAS = 3
PAUSA_SEGUNDOS = 2.0


def extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]:
    if "validateCaptcha" in html or "Digite os caracteres" in html:
        raise ColetaBloqueada("Amazon serviu captcha")

    arvore = HTMLParser(html)
    ofertas = []
    for card in arvore.css('div[data-component-type="s-search-result"]'):
        asin = card.attributes.get("data-asin", "")
        if len(asin) != 10:
            continue

        titulo_no = card.css_first("h2")
        preco_no = card.css_first(".a-price > .a-offscreen")
        if not titulo_no or not preco_no:
            continue  # patrocinado sem preco, ou banner

        link_no = card.css_first('a[href*="/dp/"]')
        if not link_no:
            continue

        cheio_no = card.css_first(".a-price.a-text-price > .a-offscreen")
        imagem_no = card.css_first("img.s-image")
        preco_centavos = reais_para_centavos(preco_no.text(strip=True))
        cheio_centavos = (
            reais_para_centavos(cheio_no.text(strip=True)) if cheio_no else None
        )

        ofertas.append(
            OfertaCrua(
                loja="amazon",
                id_na_loja=asin,
                titulo=titulo_no.text(strip=True),
                preco_centavos=preco_centavos,
                preco_original_centavos=(
                    cheio_centavos if cheio_centavos and cheio_centavos > preco_centavos else None
                ),
                em_estoque=True,  # a busca so lista o que da para comprar
                url=urljoin(BASE, link_no.attributes.get("href", "")).split("?")[0],
                url_imagem=imagem_no.attributes.get("src") if imagem_no else None,
                condicao=Condicao.NOVO,
                vendedor=None,  # a busca nao expoe vendedor de forma confiavel
                reputacao_vendedor=None,
                coletado_em=coletado_em,
            )
        )
    return ofertas


class AdaptadorAmazon:
    loja = "amazon"

    async def buscar(self, termo: str) -> list[OfertaCrua]:
        coletado_em = datetime.now(UTC)
        todas: list[OfertaCrua] = []
        async with httpx.AsyncClient(
            headers={
                "User-Agent": UA,
                "Accept-Language": "pt-BR,pt;q=0.9",
                "Accept": "text/html,application/xhtml+xml",
            },
            follow_redirects=True, timeout=30,
        ) as cliente:
            for pagina in range(1, PAGINAS + 1):
                if pagina > 1:
                    await asyncio.sleep(PAUSA_SEGUNDOS)
                resposta = await cliente.get(
                    f"{BASE}/s", params={"k": termo, "page": pagina}
                )
                if resposta.status_code == 503:
                    raise ColetaBloqueada("Amazon respondeu 503 (throttling)")
                resposta.raise_for_status()
                da_pagina = extrair_do_html(resposta.text, coletado_em)
                if not da_pagina:
                    break
                todas.extend(da_pagina)
        return todas
```

Acrescentar ao registro:

```python
# ddr5_radar/coleta/adaptadores/__init__.py
from ddr5_radar.coleta.adaptadores.amazon import AdaptadorAmazon
from ddr5_radar.coleta.adaptadores.kabum import AdaptadorKabum

ADAPTADORES = {
    "kabum": AdaptadorKabum(),
    "amazon": AdaptadorAmazon(),
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `.venv/bin/pytest tests/adaptadores/ -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add ddr5_radar/coleta/adaptadores/ tests/
git commit -m "Adaptador da Amazon BR com deteccao de captcha"
```

---

### Task 9: Adaptador Mercado Livre

**Files:**
- Create: `ddr5_radar/coleta/adaptadores/mercadolivre.py`
- Create: `tests/adaptadores/test_mercadolivre.py`
- Modify: `ddr5_radar/coleta/adaptadores/__init__.py`

**Interfaces:**
- Consumes: `carregar_config` (Task 1), `OfertaCrua`, `Condicao`, `AdaptadorNaoConfigurado`, `ColetaBloqueada`
- Produces: `AdaptadorMercadoLivre` (`loja = "mercadolivre"`) e `converter_resultado(item: dict, coletado_em: datetime) -> OfertaCrua`

**Diferente de todo o resto:** aqui há API oficial, mas ela exige token. A busca pública deixou de responder sem autenticação (verificado em 2026-08-24: HTTP 403). O token sai de um app grátis criado em https://developers.mercadolivre.com.br, fluxo `client_credentials`.

Testado com `respx` (mock de httpx), sem rede.

- [ ] **Step 1: Escrever o teste que falha**

```python
# tests/adaptadores/test_mercadolivre.py
from datetime import UTC, datetime

import httpx
import pytest
import respx

from ddr5_radar.coleta.adaptadores.mercadolivre import (
    AdaptadorMercadoLivre, converter_resultado,
)
from ddr5_radar.contrato import (
    AdaptadorNaoConfigurado, ColetaBloqueada, Condicao,
)

ITEM = {
    "id": "MLB3612345678",
    "title": "KIT MEMORIA RAM DDR5 32GB 6000 KINGSTON FURY BEAST RGB",
    "price": 4199.9,
    "original_price": 4899.9,
    "available_quantity": 5,
    "permalink": "https://produto.mercadolivre.com.br/MLB-3612345678-x",
    "thumbnail": "https://http2.mlstatic.com/x.jpg",
    "condition": "new",
    "seller": {"id": 123, "nickname": "LOJA_HARDWARE"},
}


def test_converte_item_da_api():
    oferta = converter_resultado(ITEM, datetime.now(UTC))
    assert oferta.loja == "mercadolivre"
    assert oferta.id_na_loja == "MLB3612345678"
    assert oferta.preco_centavos == 419990
    assert oferta.preco_original_centavos == 489990
    assert oferta.em_estoque is True
    assert oferta.condicao is Condicao.NOVO
    assert oferta.vendedor == "LOJA_HARDWARE"


def test_sem_estoque_quando_quantidade_zero():
    item = ITEM | {"available_quantity": 0}
    assert converter_resultado(item, datetime.now(UTC)).em_estoque is False


def test_usado_e_marcado_como_usado():
    item = ITEM | {"condition": "used"}
    assert converter_resultado(item, datetime.now(UTC)).condicao is Condicao.USADO


def test_sem_preco_original_fica_none():
    item = {k: v for k, v in ITEM.items() if k != "original_price"}
    assert converter_resultado(item, datetime.now(UTC)).preco_original_centavos is None


async def test_sem_credencial_avisa_que_falta_configuracao(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@h/d")
    monkeypatch.delenv("ML_CLIENT_ID", raising=False)
    monkeypatch.delenv("ML_CLIENT_SECRET", raising=False)
    with pytest.raises(AdaptadorNaoConfigurado, match="ML_CLIENT_ID"):
        await AdaptadorMercadoLivre().buscar("ddr5")


@respx.mock
async def test_busca_usa_o_token_obtido(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@h/d")
    monkeypatch.setenv("ML_CLIENT_ID", "id")
    monkeypatch.setenv("ML_CLIENT_SECRET", "segredo")

    respx.post("https://api.mercadolibre.com/oauth/token").mock(
        return_value=httpx.Response(200, json={"access_token": "T0KEN"})
    )
    rota = respx.get("https://api.mercadolibre.com/sites/MLB/search").mock(
        return_value=httpx.Response(200, json={"results": [ITEM]})
    )

    ofertas = await AdaptadorMercadoLivre().buscar("ddr5")

    assert len(ofertas) == 1
    assert rota.calls[0].request.headers["Authorization"] == "Bearer T0KEN"


@respx.mock
async def test_403_na_busca_vira_bloqueio(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://u:p@h/d")
    monkeypatch.setenv("ML_CLIENT_ID", "id")
    monkeypatch.setenv("ML_CLIENT_SECRET", "segredo")

    respx.post("https://api.mercadolibre.com/oauth/token").mock(
        return_value=httpx.Response(200, json={"access_token": "T0KEN"})
    )
    respx.get("https://api.mercadolibre.com/sites/MLB/search").mock(
        return_value=httpx.Response(403, json={"message": "forbidden"})
    )

    with pytest.raises(ColetaBloqueada):
        await AdaptadorMercadoLivre().buscar("ddr5")
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/adaptadores/test_mercadolivre.py -v`
Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Implementar**

```python
# ddr5_radar/coleta/adaptadores/mercadolivre.py
"""Mercado Livre: unica loja com API oficial -- e a unica que exige token.

A busca publica sem autenticacao passou a responder 403 (verificado em
2026-08-24). O token vem de um app gratuito, fluxo client_credentials.
"""
import asyncio
from datetime import UTC, datetime

import httpx

from ddr5_radar.contrato import (
    AdaptadorNaoConfigurado, ColetaBloqueada, Condicao, OfertaCrua,
    reais_para_centavos,
)
from ddr5_radar.config import carregar_config

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
            token = await self._token(cliente, config.ml_client_id, config.ml_client_secret)
            todas: list[OfertaCrua] = []
            for pagina in range(PAGINAS):
                if pagina:
                    await asyncio.sleep(PAUSA_SEGUNDOS)
                resposta = await cliente.get(
                    f"{API}/sites/MLB/search",
                    params={"q": termo, "limit": POR_PAGINA, "offset": pagina * POR_PAGINA},
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

    async def _token(self, cliente: httpx.AsyncClient, client_id: str, secret: str) -> str:
        resposta = await cliente.post(
            f"{API}/oauth/token",
            data={
                "grant_type": "client_credentials",
                "client_id": client_id,
                "client_secret": secret,
            },
        )
        if resposta.status_code != 200:
            raise ColetaBloqueada(f"Mercado Livre negou o token: {resposta.text[:200]}")
        return resposta.json()["access_token"]
```

Acrescentar `"mercadolivre": AdaptadorMercadoLivre()` ao dicionário `ADAPTADORES`.

- [ ] **Step 4: Rodar e ver passar**

Run: `.venv/bin/pytest tests/adaptadores/test_mercadolivre.py -v`
Expected: PASS, 6 testes

- [ ] **Step 5: Commit**

```bash
git add ddr5_radar/coleta/adaptadores/ tests/adaptadores/test_mercadolivre.py
git commit -m "Adaptador do Mercado Livre via API oficial com token"
```

---

### Task 10: Navegador compartilhado e adaptador Pichau

**Files:**
- Create: `ddr5_radar/coleta/navegador.py`
- Create: `ddr5_radar/coleta/adaptadores/pichau.py`
- Create: `tests/adaptadores/test_pichau.py`
- Modify: `ddr5_radar/coleta/adaptadores/__init__.py`

**Interfaces:**
- Consumes: `OfertaCrua`, `Condicao`, `ColetaBloqueada`, `reais_para_centavos`
- Produces:
  - `abrir_navegador(headless: bool = True)` — context manager async que devolve uma `Page` do Playwright já configurada
  - `AdaptadorPichau` (`loja = "pichau"`) e `extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]`

**Leia isto antes de começar — reconhecimento feito em 2026-08-24 com Playwright real:**

1. **Headless é bloqueado.** Com `headless=True` a Pichau devolve a página
   "Site em Manutenção – Pru Pru". Com `headless=False` (navegador visível) a
   página carrega de verdade: título "Memória RAM para PC e notebook em
   promoção". No GitHub Actions isso exige `xvfb-run` (já previsto na Task 15).
2. **O bloqueio é intermitente.** A mesma URL, no mesmo navegador visível,
   ora carrega ora devolve 404/manutenção.
3. **As classes CSS são hasheadas pelo MUI** (`mui-3ij2mi-strikeThrough`,
   `mui-1ww3op6-price_vista_text`). Elas mudam a cada build da Pichau —
   qualquer seletor apoiado nelas quebra sozinho em semanas. Por isso o
   adaptador se apoia em **estrutura** (`h2`, `a[href]`) e lê o preço por
   **regex sobre o texto do card**, no padrão "de R$ X por R$ Y".
4. **Estrutura confirmada do card:** container com classe contendo
   `MuiGrid2-grid-lg-3`, título em `h2`, link em `a[href]` com caminho
   relativo (`/memoria-kingston-fury-...`), imagem em `img`.

**Decisão: a Pichau entra DESLIGADA no v1.** Não consegui capturar uma fixture
de listagem de memória — o bloqueio impediu. Escrever seletor sem ver o HTML
real seria chute, e chute aqui vira preço errado no banco. O adaptador fica
escrito e testado contra o que foi possível observar, mas fora do dicionário
`ADAPTADORES`, com um passo claro para ligá-lo. O sistema roda com 4 lojas —
exatamente o que a spec §14 previu.

- [ ] **Step 1: Implementar o navegador compartilhado**

```python
# ddr5_radar/coleta/navegador.py
"""Contexto Playwright unico, usado por Pichau e Terabyte.

Abrir um Chromium por loja custaria o dobro de memoria e de tempo no
runner do GitHub Actions.

headless=False existe por causa da Pichau: com headless=True ela devolve
a pagina de manutencao (verificado em 2026-08-24). No Actions, quem roda
sem headless precisa de xvfb-run.
"""
from contextlib import asynccontextmanager

from playwright.async_api import Page, async_playwright

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
)


@asynccontextmanager
async def abrir_navegador(headless: bool = True):
    async with async_playwright() as p:
        navegador = await p.chromium.launch(
            headless=headless,
            args=["--disable-blink-features=AutomationControlled"],
        )
        contexto = await navegador.new_context(
            user_agent=UA,
            locale="pt-BR",
            viewport={"width": 1440, "height": 1000},
            extra_http_headers={"Accept-Language": "pt-BR,pt;q=0.9"},
        )
        await contexto.add_init_script(
            "Object.defineProperty(navigator,'webdriver',{get:()=>undefined})"
        )
        pagina: Page = await contexto.new_page()
        try:
            yield pagina
        finally:
            await contexto.close()
            await navegador.close()
```

- [ ] **Step 2: Escrever o teste que falha**

```python
# tests/adaptadores/test_pichau.py
"""A Pichau nao permitiu capturar fixture de listagem (bloqueio intermitente).

Estes testes cobrem o que da para cobrir sem ela: a deteccao de bloqueio e a
leitura de preco no formato "de R$ X por R$ Y", que foi observado no HTML real
em 2026-08-24. O teste de listagem fica marcado para quando a fixture existir.
"""
from datetime import UTC, datetime
from pathlib import Path

import pytest

from ddr5_radar.coleta.adaptadores.pichau import extrair_do_html, ler_precos
from ddr5_radar.contrato import ColetaBloqueada

FIXTURE = Path(__file__).parent.parent / "fixtures" / "pichau_lista_memoria.html"


def test_pagina_de_manutencao_vira_bloqueio():
    html = "<html><head><title>Site em Manutenção - Pru Pru</title></head><body></body></html>"
    with pytest.raises(ColetaBloqueada, match="Manuten"):
        extrair_do_html(html, datetime.now(UTC))


def test_pagina_404_vira_bloqueio():
    html = "<html><head><title>404 - Página não encontrada | Pichau</title></head></html>"
    with pytest.raises(ColetaBloqueada, match="404"):
        extrair_do_html(html, datetime.now(UTC))


def test_le_preco_no_padrao_de_por():
    # texto real de card observado em 2026-08-24
    texto = "33%OFF90UNIDVentoinha Pichau Ventus NX deR$ 70,58porR$ 39,99À vista"
    atual, cheio = ler_precos(texto)
    assert atual == 3999
    assert cheio == 7058


def test_le_preco_quando_nao_ha_desconto():
    atual, cheio = ler_precos("Memória Kingston Fury Beast 16GB DDR5 R$ 1.899,99 À vista")
    assert atual == 189999
    assert cheio is None


def test_card_sem_preco_nenhum_e_ignorado():
    assert ler_precos("Memória Kingston Fury Beast 16GB DDR5 Avise-me") == (None, None)


@pytest.mark.skipif(not FIXTURE.exists(), reason="fixture da Pichau ainda nao capturada")
def test_extrai_listagem_quando_a_fixture_existir():
    ofertas = extrair_do_html(FIXTURE.read_text(encoding="utf-8"), datetime.now(UTC))
    assert len(ofertas) >= 10
    assert all(o.url.startswith("https://www.pichau.com.br/") for o in ofertas)
    assert all(o.preco_centavos > 1000 for o in ofertas)
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/adaptadores/test_pichau.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.coleta.adaptadores.pichau'`

- [ ] **Step 4: Implementar o adaptador**

```python
# ddr5_radar/coleta/adaptadores/pichau.py
"""Pichau: a loja mais hostil das cinco.

Reconhecimento de 2026-08-24:
  - headless=True devolve "Site em Manutencao - Pru Pru"; headed carrega
  - o bloqueio e intermitente mesmo com navegador visivel
  - as classes CSS sao hasheadas pelo MUI e mudam a cada build deles

Por isso nada aqui depende de nome de classe: o card e localizado pela
classe estrutural do grid do MUI, o titulo por <h2>, o link por <a href>,
e o preco por regex no texto -- padrao "de R$ X por R$ Y".
"""
import re
from datetime import UTC, datetime
from urllib.parse import urljoin

from selectolax.parser import HTMLParser

from ddr5_radar.coleta.navegador import abrir_navegador
from ddr5_radar.contrato import (
    ColetaBloqueada, Condicao, OfertaCrua, reais_para_centavos,
)

BASE = "https://www.pichau.com.br"
LISTAGEM = f"{BASE}/hardware/memorias"

SELETOR_CARD = "div[class*='MuiGrid2-grid-lg-3']"
PRECO_POR = re.compile(r"por\s*R\$\s*([\d.,]+)", re.I)
PRECO_DE = re.compile(r"\bde\s*R\$\s*([\d.,]+)", re.I)
PRECO_QUALQUER = re.compile(r"R\$\s*([\d.,]+)")


def ler_precos(texto: str) -> tuple[int | None, int | None]:
    """Devolve (preco_atual, preco_cheio) em centavos.

    Na Pichau o card escreve "de R$ 70,58 por R$ 39,99" quando ha desconto,
    e so um "R$ X" quando nao ha.
    """
    por = PRECO_POR.search(texto)
    de = PRECO_DE.search(texto)
    if por:
        atual = reais_para_centavos(por.group(1))
        cheio = reais_para_centavos(de.group(1)) if de else None
        return atual, (cheio if cheio and cheio > atual else None)

    qualquer = PRECO_QUALQUER.search(texto)
    return (reais_para_centavos(qualquer.group(1)), None) if qualquer else (None, None)


def extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]:
    arvore = HTMLParser(html)
    titulo_pagina = arvore.css_first("title")
    rotulo = titulo_pagina.text() if titulo_pagina else ""
    if "Manuten" in rotulo:
        raise ColetaBloqueada("Pichau devolveu a pagina de Manutencao (anti-bot)")
    if "404" in rotulo:
        raise ColetaBloqueada("Pichau devolveu 404 — URL de listagem mudou ou bloqueio")

    ofertas = []
    for card in arvore.css(SELETOR_CARD):
        link = card.css_first("a[href]")
        titulo = card.css_first("h2")
        if not (link and titulo):
            continue

        atual, cheio = ler_precos(card.text(strip=True))
        if atual is None:
            continue  # sem preco visivel: esgotado ou "avise-me"

        caminho = link.attributes.get("href", "")
        imagem = card.css_first("img")
        ofertas.append(
            OfertaCrua(
                loja="pichau",
                id_na_loja=caminho.strip("/").split("/")[-1],
                titulo=titulo.text(strip=True),
                preco_centavos=atual,
                preco_original_centavos=cheio,
                em_estoque=True,
                url=urljoin(BASE, caminho),
                url_imagem=imagem.attributes.get("src") if imagem else None,
                condicao=Condicao.NOVO,
                vendedor="Pichau",
                reputacao_vendedor=None,
                coletado_em=coletado_em,
            )
        )
    return ofertas


class AdaptadorPichau:
    loja = "pichau"

    async def buscar(self, termo: str) -> list[OfertaCrua]:
        coletado_em = datetime.now(UTC)
        # headless=False de proposito: headless e bloqueado (ver docstring)
        async with abrir_navegador(headless=False) as pagina:
            await pagina.goto(LISTAGEM, wait_until="domcontentloaded", timeout=45_000)
            await pagina.wait_for_timeout(8_000)
            await pagina.mouse.wheel(0, 4_000)
            await pagina.wait_for_timeout(3_000)
            html = await pagina.content()
        return extrair_do_html(html, coletado_em)
```

**O registro NÃO recebe a Pichau nesta task.** Ela fica escrita e fora do ar:

```python
# ddr5_radar/coleta/adaptadores/__init__.py
from ddr5_radar.coleta.adaptadores.amazon import AdaptadorAmazon
from ddr5_radar.coleta.adaptadores.kabum import AdaptadorKabum
from ddr5_radar.coleta.adaptadores.mercadolivre import AdaptadorMercadoLivre

# Pichau fica de fora ate existir uma fixture de listagem capturada com
# sucesso (ver Task 10). Ligar = importar AdaptadorPichau e acrescentar aqui.
ADAPTADORES = {
    "kabum": AdaptadorKabum(),
    "amazon": AdaptadorAmazon(),
    "mercadolivre": AdaptadorMercadoLivre(),
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `.venv/bin/pytest tests/adaptadores/test_pichau.py -v`
Expected: PASS, 5 testes e 1 pulado (`test_extrai_listagem_quando_a_fixture_existir`)

- [ ] **Step 6: Tentar capturar a fixture — e ligar a Pichau se conseguir**

```bash
.venv/bin/python scripts/capturar_fixture.py pichau
```

O script precisa usar `headless=False` para a Pichau. Se o arquivo salvo tiver
título "Memória RAM..." e mais de 10 cards, renomeá-lo para
`tests/fixtures/pichau_lista_memoria.html`, rodar os testes de novo (o teste
pulado agora roda) e só então acrescentar a Pichau ao `ADAPTADORES`.

Se vier "Manutenção" ou "404": deixar como está e seguir. Quatro lojas bastam,
e o Sinal 1 exige três (spec §8).

- [ ] **Step 7: Commit**

```bash
git add ddr5_radar/coleta/ tests/adaptadores/test_pichau.py
git commit -m "Navegador compartilhado e adaptador da Pichau (desligado no v1)"
```

---

### Task 11: Adaptador Terabyte

**Files:**
- Create: `ddr5_radar/coleta/adaptadores/terabyte.py`
- Create: `tests/fixtures/terabyte_busca_ddr5.html` (já capturada — ver Step 1)
- Create: `tests/adaptadores/test_terabyte.py`
- Modify: `ddr5_radar/coleta/adaptadores/__init__.py`

**Interfaces:**
- Consumes: `abrir_navegador` (Task 10), `OfertaCrua`, `Condicao`, `ColetaBloqueada`, `reais_para_centavos`
- Produces: `AdaptadorTerabyte` (`loja = "terabyte"`) e `extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]`

**Reconhecimento feito em 2026-08-24 — ao contrário da Pichau, aqui deu tudo certo:**

- `headless=True` funciona. Não precisa de xvfb.
- A busca `https://www.terabyteshop.com.br/busca?str=ddr5` devolveu 29 produtos.
- As classes são **legíveis e estáveis** (não hasheadas):

| Elemento | Seletor |
|---|---|
| card | `div.product-item` |
| título e link | `a.product-item__name` (href relativo `/produto/22360/slug`) |
| preço | `div.product-item__new-price` |
| preço cheio | `div.product-item__old-price` |
| imagem | `img.image-thumbnail` |

- **Atenção:** a busca traz coisa que não é memória — `PC Gamer Plataforma AMD
  Ryzen 7000 DDR5 AM5` apareceu como primeiro resultado. Quem descarta é o
  `eh_memoria` da Task 4, na persistência. O adaptador coleta tudo; filtrar não
  é trabalho dele.
- Card sem preço existe: o PC custom mostra "Monte do seu jeito" no lugar do
  valor. Card sem `R$` é ignorado.

- [ ] **Step 1: Capturar a fixture**

Run: `.venv/bin/python scripts/capturar_fixture.py terabyte`
Expected: `tests/fixtures/terabyte_busca_ddr5.html` com ~750 KB

- [ ] **Step 2: Escrever o teste que falha**

```python
# tests/adaptadores/test_terabyte.py
from datetime import UTC, datetime
from pathlib import Path

import pytest

from ddr5_radar.coleta.adaptadores.terabyte import extrair_do_html
from ddr5_radar.contrato import ColetaBloqueada

FIXTURE = Path(__file__).parent.parent / "fixtures" / "terabyte_busca_ddr5.html"


@pytest.fixture
def ofertas():
    return extrair_do_html(FIXTURE.read_text(encoding="utf-8"), datetime.now(UTC))


def test_encontra_produtos(ofertas):
    assert len(ofertas) >= 20


def test_preco_em_centavos_inteiros(ofertas):
    for oferta in ofertas:
        assert isinstance(oferta.preco_centavos, int)
        assert oferta.preco_centavos > 1000


def test_url_absoluta_de_produto(ofertas):
    for oferta in ofertas:
        assert oferta.url.startswith("https://www.terabyteshop.com.br/produto/")


def test_id_na_loja_nao_repete(ofertas):
    ids = [o.id_na_loja for o in ofertas]
    assert len(ids) == len(set(ids))


def test_titulo_preenchido(ofertas):
    assert all(len(o.titulo.strip()) > 10 for o in ofertas)


def test_traz_memoria_de_verdade(ofertas):
    # a busca mistura PC gamer e placa-mae; o filtro e da Task 4, mas o
    # adaptador tem que estar trazendo memoria de fato
    titulos = " ".join(o.titulo.lower() for o in ofertas)
    assert "memória ddr5" in titulos or "memoria ddr5" in titulos


def test_card_sem_preco_e_ignorado():
    html = """
    <div class="product-item">
      <a class="product-item__name" href="/produto/1/pc-custom">PC Gamer Custom Monte do seu jeito</a>
      <div class="product-item__new-price">Monte do seu jeito</div>
    </div>
    """
    assert extrair_do_html(html, datetime.now(UTC)) == []


def test_html_sem_card_nenhum_vira_bloqueio():
    with pytest.raises(ColetaBloqueada):
        extrair_do_html("<html><body></body></html>", datetime.now(UTC))
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/adaptadores/test_terabyte.py -v`
Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 4: Implementar**

```python
# ddr5_radar/coleta/adaptadores/terabyte.py
"""Terabyte: WAF bloqueia curl (403), mas Playwright headless passa.

Seletores confirmados em 2026-08-24 e legiveis -- nada de classe hasheada,
ao contrario da Pichau.
"""
from datetime import UTC, datetime
from urllib.parse import urljoin

from selectolax.parser import HTMLParser

from ddr5_radar.coleta.navegador import abrir_navegador
from ddr5_radar.contrato import (
    ColetaBloqueada, Condicao, OfertaCrua, reais_para_centavos,
)

BASE = "https://www.terabyteshop.com.br"
BUSCA = f"{BASE}/busca?str={{termo}}"

SELETOR_CARD = "div.product-item"
SELETOR_NOME = "a.product-item__name"
SELETOR_PRECO = "div.product-item__new-price"
SELETOR_PRECO_CHEIO = "div.product-item__old-price"
SELETOR_IMAGEM = "img.image-thumbnail"


def extrair_do_html(html: str, coletado_em: datetime) -> list[OfertaCrua]:
    arvore = HTMLParser(html)
    cards = arvore.css(SELETOR_CARD)
    if not cards:
        raise ColetaBloqueada(
            "Terabyte nao devolveu nenhum card — bloqueio ou mudanca de layout"
        )

    ofertas = []
    for card in cards:
        nome = card.css_first(SELETOR_NOME)
        preco = card.css_first(SELETOR_PRECO)
        if not (nome and preco):
            continue

        texto_preco = preco.text(strip=True)
        if "R$" not in texto_preco:
            continue  # "Monte do seu jeito" (PC custom) ou esgotado

        caminho = nome.attributes.get("href", "")
        cheio = card.css_first(SELETOR_PRECO_CHEIO)
        imagem = card.css_first(SELETOR_IMAGEM)
        preco_centavos = reais_para_centavos(texto_preco)
        cheio_centavos = (
            reais_para_centavos(cheio.text(strip=True))
            if cheio and "R$" in cheio.text() else None
        )

        ofertas.append(
            OfertaCrua(
                loja="terabyte",
                id_na_loja=caminho.strip("/").split("/")[1],  # /produto/22360/slug
                titulo=nome.text(strip=True),
                preco_centavos=preco_centavos,
                preco_original_centavos=(
                    cheio_centavos
                    if cheio_centavos and cheio_centavos > preco_centavos else None
                ),
                em_estoque=True,
                url=urljoin(BASE, caminho),
                url_imagem=(
                    imagem.attributes.get("data-src") or imagem.attributes.get("src")
                    if imagem else None
                ),
                condicao=Condicao.NOVO,
                vendedor="TerabyteShop",
                reputacao_vendedor=None,
                coletado_em=coletado_em,
            )
        )
    return ofertas


class AdaptadorTerabyte:
    loja = "terabyte"

    async def buscar(self, termo: str) -> list[OfertaCrua]:
        coletado_em = datetime.now(UTC)
        async with abrir_navegador() as pagina:  # headless funciona aqui
            await pagina.goto(
                BUSCA.format(termo=termo), wait_until="domcontentloaded", timeout=45_000
            )
            await pagina.wait_for_timeout(5_000)
            html = await pagina.content()
        return extrair_do_html(html, coletado_em)
```

Registro final do v1 — quatro lojas ligadas:

```python
# ddr5_radar/coleta/adaptadores/__init__.py
from ddr5_radar.coleta.adaptadores.amazon import AdaptadorAmazon
from ddr5_radar.coleta.adaptadores.kabum import AdaptadorKabum
from ddr5_radar.coleta.adaptadores.mercadolivre import AdaptadorMercadoLivre
from ddr5_radar.coleta.adaptadores.terabyte import AdaptadorTerabyte

# Pichau segue de fora ate a fixture ser capturada (Task 10 Step 6).
ADAPTADORES = {
    "kabum": AdaptadorKabum(),
    "amazon": AdaptadorAmazon(),
    "mercadolivre": AdaptadorMercadoLivre(),
    "terabyte": AdaptadorTerabyte(),
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `.venv/bin/pytest tests/adaptadores/ -v`
Expected: PASS em todos os adaptadores

- [ ] **Step 6: Commit**

```bash
git add ddr5_radar/coleta/adaptadores/ tests/
git commit -m "Adaptador da Terabyte com seletores confirmados"
```

---

### Task 12: Executor — isolamento de falhas

**Files:**
- Create: `ddr5_radar/coleta/executor.py`
- Create: `tests/test_executor.py`

**Interfaces:**
- Consumes: `Adaptador`, `ColetaBloqueada`, `AdaptadorNaoConfigurado`, `OfertaCrua`
- Produces:
  - `ResultadoLoja` — dataclass: `loja: str`, `ofertas: list[OfertaCrua]`, `sucesso: bool`, `erro: str | None`, `duracao_ms: int`
  - `async def coletar_tudo(termo: str, adaptadores: list[Adaptador], timeout_segundos: int = 120) -> list[ResultadoLoja]`

**Requisito central (spec §6):** loja quebrada não pode derrubar a rodada. Cinco adaptadores rodam concorrentes; cada exceção é capturada, transformada em `ResultadoLoja(sucesso=False)`, e a rodada continua. Uma loja que trava é cortada por timeout — o runner do GitHub Actions não pode ficar 15 minutos preso esperando a Terabyte.

- [ ] **Step 1: Escrever o teste que falha**

```python
# tests/test_executor.py
import asyncio
from datetime import UTC, datetime

from ddr5_radar.contrato import (
    AdaptadorNaoConfigurado, ColetaBloqueada, Condicao, OfertaCrua,
)
from ddr5_radar.coleta.executor import coletar_tudo


def _oferta(loja: str) -> OfertaCrua:
    return OfertaCrua(
        loja=loja, id_na_loja="1", titulo="Memória DDR5 16GB 5600MHz Kingston Fury Beast",
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/test_executor.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.coleta.executor'`

- [ ] **Step 3: Implementar**

```python
# ddr5_radar/coleta/executor.py
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
```

- [ ] **Step 4: Rodar e ver passar**

Run: `.venv/bin/pytest tests/test_executor.py -v`
Expected: PASS, 6 testes

- [ ] **Step 5: Commit**

```bash
git add ddr5_radar/coleta/executor.py tests/test_executor.py
git commit -m "Executor que isola a falha de cada loja"
```

---

### Task 13: CLI de coleta

**Files:**
- Create: `ddr5_radar/cli.py`
- Create: `tests/test_cli.py`

**Interfaces:**
- Consumes: `ADAPTADORES` (Task 11), `coletar_tudo` (Task 12), persistência (Task 6), `criar_sessao` (Task 5)
- Produces: `async def executar_coleta(termo: str, lojas: list[str] | None = None) -> str` — devolve o resumo em texto; e o ponto de entrada `python -m ddr5_radar.cli coletar`

Este é o único arquivo que conhece todas as camadas — é a costura, e por isso mora sozinho.

- [ ] **Step 1: Escrever o teste que falha**

```python
# tests/test_cli.py
from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

from ddr5_radar.cli import executar_coleta
from ddr5_radar.contrato import Condicao, OfertaCrua
from ddr5_radar.nucleo.modelos import Base, Oferta, SaudeAdaptador


class AdaptadorFalso:
    loja = "falsa"

    async def buscar(self, termo):
        return [
            OfertaCrua(
                loja="falsa", id_na_loja="1",
                titulo="Memória Kingston Fury Beast, 16GB, 5600MHz, DDR5, CL40 - KF556C40BB-16",
                preco_centavos=189999, preco_original_centavos=None, em_estoque=True,
                url="https://x", url_imagem=None, condicao=Condicao.NOVO,
                vendedor=None, reputacao_vendedor=None, coletado_em=datetime.now(UTC),
            )
        ]


class AdaptadorCaido:
    loja = "caida"
    async def buscar(self, termo): raise RuntimeError("caiu")


@pytest.fixture
def sessao_falsa(monkeypatch):
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    fabrica = sessionmaker(engine, expire_on_commit=False)
    monkeypatch.setattr("ddr5_radar.cli.criar_sessao", lambda: fabrica)
    return fabrica


async def test_coleta_ponta_a_ponta_grava_no_banco(sessao_falsa, monkeypatch):
    monkeypatch.setattr("ddr5_radar.cli.ADAPTADORES", {"falsa": AdaptadorFalso()})
    resumo = await executar_coleta("ddr5")

    with sessao_falsa() as s:
        oferta = s.scalars(select(Oferta)).one()
        assert oferta.part_number == "KF556C40BB-16"
    assert "1 nova" in resumo


async def test_loja_caida_e_registrada_e_a_rodada_termina(sessao_falsa, monkeypatch):
    monkeypatch.setattr(
        "ddr5_radar.cli.ADAPTADORES",
        {"falsa": AdaptadorFalso(), "caida": AdaptadorCaido()},
    )
    resumo = await executar_coleta("ddr5")

    with sessao_falsa() as s:
        saude = {x.loja: x for x in s.scalars(select(SaudeAdaptador)).all()}
    assert saude["caida"].sucesso is False
    assert saude["falsa"].sucesso is True
    assert "caida" in resumo


async def test_filtro_de_lojas_respeitado(sessao_falsa, monkeypatch):
    monkeypatch.setattr(
        "ddr5_radar.cli.ADAPTADORES",
        {"falsa": AdaptadorFalso(), "caida": AdaptadorCaido()},
    )
    await executar_coleta("ddr5", lojas=["falsa"])

    with sessao_falsa() as s:
        assert {x.loja for x in s.scalars(select(SaudeAdaptador)).all()} == {"falsa"}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `.venv/bin/pytest tests/test_cli.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ddr5_radar.cli'`

- [ ] **Step 3: Implementar**

```python
# ddr5_radar/cli.py
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
        f"{resumo.descartadas} descartada(s) por não ser DDR5"
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
```

- [ ] **Step 4: Rodar e ver passar**

Run: `.venv/bin/pytest -v`
Expected: PASS, toda a suíte

- [ ] **Step 5: Commit**

```bash
git add ddr5_radar/cli.py tests/test_cli.py
git commit -m "CLI de coleta costurando coleta, normalizacao e persistencia"
```

---

### Task 14: Testes de fumaça contra as lojas reais

**Files:**
- Create: `tests/test_fumaca.py`

**Interfaces:**
- Consumes: `ADAPTADORES` (Task 11)
- Produces: nada de código de produção — é a rede de alarme de "o adaptador apodreceu"

Estes testes **batem na loja de verdade** e ficam desmarcados por padrão (`addopts = "-m 'not rede'"`, Task 1). Rodar sob demanda, quando uma loja parar de trazer resultado, para saber se o problema é o formato da loja ou o código.

- [ ] **Step 1: Escrever os testes**

```python
# tests/test_fumaca.py
"""Batem nas lojas de verdade. Rodar com: pytest -m rede

Nao rodam na suite normal nem no CI. Servem para responder uma pergunta
so: "a loja mudou de formato?"
"""
import pytest

from ddr5_radar.coleta.adaptadores import ADAPTADORES

pytestmark = pytest.mark.rede


@pytest.mark.parametrize("nome", sorted(ADAPTADORES))
async def test_loja_ainda_devolve_produto(nome):
    ofertas = await ADAPTADORES[nome].buscar("ddr5")

    assert len(ofertas) >= 5, f"{nome} devolveu {len(ofertas)} ofertas"
    primeira = ofertas[0]
    assert primeira.preco_centavos > 1000
    assert primeira.titulo.strip()
    assert primeira.url.startswith("https://")
    assert primeira.id_na_loja


@pytest.mark.parametrize("nome", sorted(ADAPTADORES))
async def test_titulos_parecem_memoria(nome):
    ofertas = await ADAPTADORES[nome].buscar("ddr5")
    com_ddr5 = [o for o in ofertas if "ddr5" in o.titulo.lower()]
    assert len(com_ddr5) >= len(ofertas) // 2, (
        f"{nome}: só {len(com_ddr5)} de {len(ofertas)} títulos mencionam DDR5 — "
        "a busca pode ter mudado de comportamento"
    )
```

- [ ] **Step 2: Rodar contra a rede**

Run: `.venv/bin/pytest -m rede -v`
Expected: PASS para Kabum e Amazon. Pichau, Terabyte e Mercado Livre dependem dos seletores das Tasks 10-11 e da credencial da Task 9 — se falharem aqui, o erro diz qual.

- [ ] **Step 3: Confirmar que a suíte normal continua sem rede**

Run: `.venv/bin/pytest -v`
Expected: PASS, e nenhum teste de `test_fumaca.py` na lista

- [ ] **Step 4: Commit**

```bash
git add tests/test_fumaca.py
git commit -m "Testes de fumaca contra as lojas reais, fora da suite padrao"
```

---

### Task 15: Coleta automática no GitHub Actions

**Files:**
- Create: `.github/workflows/coletar.yml`
- Create: `README.md`

**Interfaces:**
- Consumes: `python -m ddr5_radar.cli coletar` (Task 13)
- Produces: coleta rodando sozinha a cada 10 minutos

**Antes desta task, criar no GitHub:** repositório **público** (é o que torna o Actions ilimitado — spec §4) e os Secrets `DATABASE_URL`, `ML_CLIENT_ID`, `ML_CLIENT_SECRET`.

- [ ] **Step 1: Escrever o workflow**

```yaml
# .github/workflows/coletar.yml
name: coletar

on:
  schedule:
    - cron: "*/10 * * * *"
  workflow_dispatch:

# Uma rodada por vez: se a anterior ainda roda, esta espera em vez de
# duplicar preco no banco.
concurrency:
  group: coleta
  cancel-in-progress: false

jobs:
  coletar:
    runs-on: ubuntu-latest
    timeout-minutes: 12

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.13"
          cache: pip

      - name: Instalar dependências
        run: pip install -e .

      - name: Cache do Chromium
        id: cache-navegador
        uses: actions/cache@v4
        with:
          path: ~/.cache/ms-playwright
          key: playwright-chromium-${{ runner.os }}

      - name: Instalar o Chromium
        if: steps.cache-navegador.outputs.cache-hit != 'true'
        run: playwright install --with-deps chromium

      - name: Instalar dependências do sistema do Chromium
        if: steps.cache-navegador.outputs.cache-hit == 'true'
        run: playwright install-deps chromium

      # Quando a Pichau for ligada (Task 10 Step 6), ela exige navegador
      # visivel -- trocar a linha do run por:
      #   xvfb-run -a python -m ddr5_radar.cli coletar --termo ddr5
      - name: Coletar
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          ML_CLIENT_ID: ${{ secrets.ML_CLIENT_ID }}
          ML_CLIENT_SECRET: ${{ secrets.ML_CLIENT_SECRET }}
        run: python -m ddr5_radar.cli coletar --termo ddr5
```

- [ ] **Step 2: Escrever o README**

```markdown
# DDR5 Radar

Vigia o preço de memórias DDR5 nas lojas brasileiras e guarda o histórico.
Quatro lojas ligadas; a Pichau está escrita mas desligada (anti-bot). A detecção de preço bugado e o painel são o Plano 2.

## Rodar localmente

```bash
python3.13 -m venv .venv
.venv/bin/pip install -e ".[dev]"
.venv/bin/playwright install --with-deps chromium

export DATABASE_URL="postgresql+psycopg://postgres:SENHA@db.PROJETO.supabase.co:5432/postgres"
export ML_CLIENT_ID="..."      # https://developers.mercadolivre.com.br
export ML_CLIENT_SECRET="..."

.venv/bin/alembic upgrade head
.venv/bin/python -m ddr5_radar.cli coletar
```

Uma loja só: `python -m ddr5_radar.cli coletar --loja kabum`

## Testes

```bash
.venv/bin/pytest              # suíte normal, sem rede
.venv/bin/pytest -m rede      # bate nas lojas de verdade
```

## Como cada loja é lida

| Loja | Tática | Situação |
|---|---|---|
| Kabum | httpx | ✅ JSON no `__NEXT_DATA__` do HTML |
| Amazon BR | httpx | ✅ HTML da busca; serve captcha se apertar o ritmo |
| Mercado Livre | API oficial | ✅ Busca pública responde 403; exige token de app grátis |
| Terabyte | Playwright headless | ✅ WAF bloqueia curl, mas headless passa |
| Pichau | Playwright headed | ⚠️ **Desligada.** Bloqueia headless, bloqueia de forma intermitente mesmo headed, e usa classes CSS hasheadas |

Quando uma loja para de trazer resultado: `pytest -m rede -k NOME` diz se
o formato mudou. O seletor de cada loja fica no topo do seu arquivo em
`ddr5_radar/coleta/adaptadores/`.
```

- [ ] **Step 3: Disparar o workflow à mão e conferir**

No GitHub: aba Actions → workflow "coletar" → "Run workflow".
Expected: job verde, e o log terminando com algo como
`Rodada: 240 nova(s), 0 atualizada(s), 240 preço(s) gravado(s)`, com uma
linha `ok` por loja.

- [ ] **Step 4: Conferir no banco**

```sql
-- No SQL Editor do Supabase
select loja, count(*) from ofertas group by loja order by 2 desc;
select loja, sucesso, qtd_ofertas, erro from saude_adaptadores
  where rodada_id = (select max(id) from rodadas);
```

Expected: ofertas de pelo menos 3 lojas. Loja com `sucesso = false` tem o
motivo escrito em `erro` — é o que diz se falta credencial, se o seletor
quebrou ou se foi bloqueio.

- [ ] **Step 5: Commit**

```bash
git add .github/ README.md
git commit -m "Coleta automatica a cada 10 minutos no GitHub Actions"
```

---

## Verificação final do Plano 1

Antes de considerar este plano concluído:

- [ ] `.venv/bin/pytest` passa inteiro, sem rede
- [ ] `.venv/bin/pytest -m rede` passa para as 4 lojas ligadas
- [ ] O workflow do Actions rodou verde ao menos duas vezes seguidas pelo cron (não só no disparo manual)
- [ ] A tabela `ofertas` tem mais de 100 linhas
- [ ] A tabela `precos` cresce entre uma rodada e outra, mas **não** ganha uma linha por oferta a cada rodada (prova de que a gravação só-em-mudança funciona)
- [ ] `saude_adaptadores` mostra o motivo de cada loja que falhou

Com isso, existe histórico real — e o Plano 2 (detecção, aviso e painel)
pode ser escrito com números calibrados em cima de dado de verdade, em vez
de chute.

## O que fica para o Plano 2

Motor de detecção (spec §8), notificação por Telegram e Web Push (§9),
painel FastAPI com as quatro telas (§10) e o botão de compra em um toque
(§11). O schema deles já está criado; falta o comportamento.

O agrupamento de ofertas em produto — part number quando existe, chave
canônica como reserva — é a primeira tarefa do Plano 2, e depende de ver
quantas ofertas reais caíram em cada caso.

# DDR5 Radar

Vigia o preço de memórias DDR5 nas lojas brasileiras e guarda o histórico.
A detecção de preço bugado, o aviso no celular e o painel são o Plano 2.

## Rodar localmente

```bash
python3.13 -m venv .venv
.venv/bin/pip install -e ".[dev]"
.venv/bin/playwright install chromium

export DATABASE_URL="postgresql+psycopg://postgres:SENHA@db.PROJETO.supabase.co:5432/postgres"
export ML_CLIENT_ID="..."      # https://developers.mercadolivre.com.br
export ML_CLIENT_SECRET="..."

.venv/bin/alembic upgrade head
.venv/bin/python -m ddr5_radar.cli coletar
```

Uma loja só: `python -m ddr5_radar.cli coletar --loja kabum`

Para experimentar sem Postgres, `DATABASE_URL="sqlite:///$(pwd)/local.db"` funciona.

## Testes

```bash
.venv/bin/pytest              # suíte normal, sem rede
.venv/bin/pytest -m rede      # bate nas lojas de verdade
```

## Como cada loja é lida

| Loja | Tática | Situação |
|---|---|---|
| Kabum | httpx | ✅ JSON no `__NEXT_DATA__` do HTML da busca |
| Amazon BR | Playwright headless | ✅ httpx passou a receber o desafio do Akamai (`bm-verify`) |
| Mercado Livre | API oficial | ✅ Busca pública dá 403; exige token de app grátis |
| Terabyte | Playwright headless | ✅ WAF bloqueia curl, mas navegador passa |
| Pichau | Playwright headed | ⚠️ **Desligada.** Bloqueia headless, bloqueia intermitente mesmo headed, e usa classes CSS hasheadas pelo MUI |

Quando uma loja para de trazer resultado: `pytest -m rede -k NOME` diz se o
formato mudou. Os seletores de cada loja ficam no topo do arquivo dela em
`ddr5_radar/coleta/adaptadores/`.

## O que o coletor faz com o que encontra

1. Descarta o que não é memória (`PC Gamer ... DDR5`, `Placa-mãe ... DDR5`) e o
   que não é DDR5.
2. Extrai marca, linha, capacidade total do kit, módulos, velocidade, latência,
   formato (DIMM/SODIMM) e **part number** do título.
3. Grava a oferta e, **só quando o preço muda**, uma linha nova de preço. São
   144 coletas por dia: repetir o mesmo número não acrescenta informação.

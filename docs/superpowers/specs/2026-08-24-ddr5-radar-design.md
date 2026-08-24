# DDR5 Radar — Design

**Data:** 2026-08-24
**Status:** aguardando revisão do João
**Autor:** João + Claude

---

## 1. Problema

Memória DDR5 tem preço volátil e catálogo confuso (o mesmo kit é anunciado com
nome diferente em cada loja). Nesse ambiente, erro de precificação acontece —
loja publica um kit de 32GB pelo preço de um pente de 8GB, marketplace vende
kit duplo com preço unitário, promoção relâmpago some em minutos. Quem vê
primeiro compra.

Hoje não existe forma de ver isso: seria preciso abrir 5 lojas várias vezes ao
dia e comparar produtos que não têm nome em comum.

## 2. Objetivo

Um sistema que vigia sozinho o preço de DDR5 nas lojas brasileiras, detecta
quando um preço está fora da curva, e coloca João a **um toque** da compra.

Métrica de sucesso: do momento em que o preço bugado aparece até João conseguir
finalizar a compra, menos de **2 minutos** — sendo no máximo 15 segundos a
parte que depende do sistema (push → painel → checkout da loja aberto).

Métrica de qualidade: no máximo **1 alerta falso por semana** na faixa 🔴 BUG.
Alerta que grita à toa é alerta que vira ruído e deixa de ser lido.

## 3. Escopo

### Dentro (v1)

- Coleta periódica de preços de DDR5 em 5 lojas: Kabum, Pichau, Terabyte,
  Amazon BR, Mercado Livre.
- Normalização dos anúncios num identificador canônico de produto.
- Motor de detecção com dois níveis: 🔴 BUG e 🟡 PROMO.
- Painel web instalável como PWA, com alertas ao vivo, histórico de preço por
  produto e configuração de sensibilidade.
- Notificação no celular por Telegram e Web Push.
- Botão de compra que abre o caminho mais curto de cada loja.

### Fora (v1)

- **Compra automática.** O sistema nunca finaliza uma compra. Ele avisa; quem
  clica é João. (Ver §13.)
- **Armazenar dados de cartão.** O cartão fica no perfil de cada loja e no
  Apple Pay do iPhone, nunca no banco deste projeto. Guardar PAN criaria escopo
  PCI-DSS sem economizar um único toque, já que o checkout roda no site da loja
  e não há como injetar cartão nele.
- **App nativo iOS.** Exige Apple Developer Program (US$ 99/ano) e Xcode. O PWA
  com ícone na tela de início mais o push do Telegram entregam o mesmo
  resultado prático por R$ 0. Ver §14 para o caminho de upgrade.
- Outros componentes (GPU, SSD, CPU). A arquitetura de adaptadores permite
  adicionar depois, mas v1 é DDR5 e só.
- Multiusuário. Sistema de uma pessoa só, com senha única.

## 4. Pilha e infraestrutura

**Uma linguagem só: Python.** Coletor, motor de detecção, API e painel. Não há
JavaScript de build no projeto — só o HTMX servido como arquivo estático.

| Decisão | Escolha | Porquê |
|---|---|---|
| Linguagem | Python 3.12 (3.14 disponível na máquina; 3.12 é o runtime da Vercel) | Melhor ecossistema de scraping e de estatística; João já tinha experimentado Scrapling |
| Coleta HTTP | `httpx` + `selectolax` | Rápido e leve para Kabum e Amazon |
| Coleta com navegador | `playwright` (Python) | Único caminho para Pichau e Terabyte |
| Motor | Python padrão (`statistics`) | Mediana e percentil sem trazer pandas para dentro do projeto |
| Banco | Supabase Postgres (projeto novo `ddr5-radar`) | Já em uso, free tier suficiente, região sa-east-1 |
| Acesso ao banco | SQLAlchemy 2 + Alembic | Migrations versionadas; o schema nasce completo |
| Painel/API | FastAPI + Jinja2 + HTMX + Tailwind (CLI) | Página renderizada no servidor, interatividade sem framework de front |
| Host do painel | Vercel, runtime Python, `regions: ["gru1"]` | Mesmo host de sempre sem uma linha de Next; função em `iad1` com banco em São Paulo custa ~1,3s por query |
| Conexão do painel | Pooler do Supabase (porta 6543) | Serverless abre conexão a cada requisição; sem pooler o Postgres esgota |
| Coletor | GitHub Actions, cron de 10 min, repo público | Playwright não roda em serverless; Actions é ilimitado em repo público; custo R$ 0 |
| Push | Telegram Bot (principal) + Web Push VAPID (secundário) | Telegram é app nativo com push confiável no iPhone, grátis e sem build |
| Segredos | GitHub Secrets + Vercel Env | Nada de credencial no repo, que é público |

**Custo total: R$ 0/mês.**

**Limitação aceita conscientemente:** o cron do GitHub Actions entra em fila e
pode atrasar 5–15 minutos além do horário agendado. Para bugs de preço em loja
brasileira (que costumam durar de minutos a horas) é aceitável no v1. O caminho
de upgrade está em §14.

## 5. Arquitetura

```
   GitHub Actions (cron 10 min)          ─── Python
   ┌──────────────────────────────────────────┐
   │  coletor                                 │
   │  ┌────────────────────────────────────┐  │
   │  │ adaptadores (1 por loja)           │  │
   │  │  kabum · amazon    → httpx         │  │
   │  │  pichau · terabyte → playwright    │  │
   │  │  mercadolivre      → API OAuth     │  │
   │  └────────────────────────────────────┘  │
   │                 ↓ ofertas cruas          │
   │            normalizador                  │
   │                 ↓ ofertas canônicas      │
   │            motor de detecção             │
   │                 ↓ alertas                │
   │            notificador                   │
   └─────────────────┬────────────────────────┘
                     ↓
              Supabase Postgres
                     ↓
              Painel FastAPI (Vercel)   ─── Python
              PWA com ícone no iPhone
```

Fluxo em uma frase: cada loja vira ofertas cruas, o normalizador descobre que
ofertas diferentes são o mesmo produto, o motor compara os preços entre si e
contra o histórico, o que fugir da curva vira alerta — e o alerta chega no
Telegram enquanto o painel mostra o botão de comprar.

Note que o notificador vive no coletor, não no painel: a notificação precisa
sair no mesmo instante da detecção, sem esperar João abrir nada.

### Organização do código

```
ddr5_radar/
  coleta/
    adaptadores/   kabum.py  pichau.py  terabyte.py  amazon.py  mercadolivre.py
    contrato.py    OfertaCrua e o protocolo do adaptador
    executor.py    roda os adaptadores, isola falha de cada um
  nucleo/
    normalizador.py   título → chave canônica
    deteccao.py       os três sinais e os guardas
    modelos.py        tabelas SQLAlchemy
  aviso/
    telegram.py
    webpush.py
  painel/
    app.py            FastAPI
    templates/        Jinja2
  cli.py              coletar / detectar / testar-aviso
```

Cada arquivo tem um propósito só, e nenhum precisa ser lido para entender o
outro — `deteccao.py` não sabe que Playwright existe, `pichau.py` não sabe o
que é uma mediana.

## 6. Coleta

### Estado real de cada loja (verificado em 2026-08-24)

| Loja | Resposta a curl | Tática | Observação |
|---|---|---|---|
| Kabum | 200 | httpx | Preço em JSON no `__NEXT_DATA__` do HTML da busca |
| Amazon BR | 200 | httpx | HTML da busca; captcha se o ritmo apertar |
| Pichau | 403 | Playwright | Página anti-bot "Site em Manutenção – Pru Pru" |
| Terabyte | 403 | Playwright | WAF bloqueia cliente não-navegador |
| Mercado Livre | 403 | API OAuth | A busca pública fechou; exige app registrado (grátis) |

### Contrato do adaptador

Cada loja é um módulo isolado que expõe a mesma função. Quem chama não sabe se
por baixo é httpx, navegador ou API.

```python
@dataclass(frozen=True)
class OfertaCrua:
    loja: str
    id_na_loja: str              # SKU / ASIN / MLB
    titulo: str
    preco_centavos: int
    preco_original_centavos: int | None
    em_estoque: bool
    url: str
    url_imagem: str | None
    condicao: Condicao           # NOVO | USADO | RECONDICIONADO | DESCONHECIDO
    vendedor: str | None         # marketplace
    reputacao_vendedor: float | None
    coletado_em: datetime

class Adaptador(Protocol):
    loja: str
    async def buscar(self, termo: str) -> list[OfertaCrua]: ...
```

É esse contrato que garante o isolamento: quando a Pichau mudar o site, quebra
`adaptadores/pichau.py` e mais nada. O executor registra a falha, segue com as
outras quatro lojas, e o painel mostra "Pichau: sem dados há 3h".

### Conduta de coleta

Ritmo respeitoso (1 requisição a cada 2s por loja, no máximo 3 páginas de busca
por rodada), `User-Agent` honesto, nenhuma tentativa de burlar login ou
paywall, nenhuma conta falsa. Se uma loja bloquear de forma persistente, o
adaptador dela é desligado — não escalamos a briga.

## 7. Normalização — a identidade do produto

Este é o miolo do sistema. Sem ele, "comparar o preço entre lojas" é
impossível, porque o mesmo kit aparece como:

```
Kabum         Memória Kingston Fury Beast, RGB, 32GB (2x16GB), 6000MHz, DDR5, CL36, Preto
Pichau        Memoria Kingston Fury Beast RGB 32GB (2x16) DDR5 6000MHz CL36 KF560C36BBEAK2-32
Mercado Livre KIT MEMORIA RAM DDR5 32GB 6000 KINGSTON FURY BEAST RGB *ENVIO IMEDIATO*
```

O normalizador extrai atributos do título e monta uma **chave canônica**:

```
marca      kingston
linha      fury-beast
capacidade 32           (GB totais do kit)
modulos    2
velocidade 6000         (MT/s)
latencia   36           (CL)
rgb        sim
→ chave:   kingston|fury-beast|32|2|6000|36|rgb
```

Regras que importam:

- **Capacidade é sempre o total do kit**, nunca a do módulo. `2x16GB` = 32. Um
  anúncio que diz "32GB" descrevendo um pente único é um produto diferente de
  um kit 2x16 — e confundir os dois é a principal fonte de falso positivo.
- Campo não encontrado no título vira `None`, não vira chute. Uma oferta com
  atributos demais faltando não entra na comparação entre lojas; é comparada só
  contra o próprio histórico.
- A chave é derivada, nunca digitada à mão. Se o parser melhorar, as chaves são
  recalculadas sobre o histórico já coletado.
- **DDR4 aparecendo em busca de DDR5** é descartado na entrada: título com DDR4,
  ou velocidade abaixo de 4000 MT/s, não é DDR5.

Cada regra de parsing nasce de um título real coletado e vira caso de teste
(§12).

## 8. Motor de detecção

Roda depois de cada coleta, sobre a foto mais recente do mercado.

### Métrica base: preço por GB

Todos os preços viram **centavos por GB** (`preço / capacidade`). É o que
permite comparar um kit 2x16 com um 2x32 e enxergar a curva do mercado inteiro,
mesmo sem match exato de produto.

### Os três sinais

**Sinal 1 — Desvio entre lojas (o mais forte).**
Para cada chave canônica presente em 3 lojas ou mais, calcula a mediana. Uma
oferta abaixo de um limiar percentual dessa mediana é candidata. Mediana e não
média, porque uma única loja errando não pode mover a referência.

**Sinal 2 — Queda contra o próprio histórico.**
Preço atual contra a mediana dos últimos 30 dias *da mesma oferta*. Queda
brusca de uma coleta para a outra é candidata. Pega o que o Sinal 1 não pega:
produto exclusivo de uma loja, sem par para comparar.

**Sinal 3 — Posição na curva de R$/GB do mercado.**
Oferta abaixo de um percentil baixo da distribuição de R$/GB de todo o DDR5
coletado naquela rodada. Pega o produto novo no catálogo, sem histórico e sem
par, mas com preço absurdo para o mercado do dia.

### Classificação

| Selo | Quando | Intenção |
|---|---|---|
| 🔴 BUG | Sinal 1 e/ou 2 forte, com desvio grande | "Larga o que estiver fazendo" |
| 🟡 PROMO | Desvio moderado, ou menor preço histórico do produto | "Vale olhar quando puder" |

### Valores iniciais dos limiares

Ficam em **configuração no painel**, não no código — mas o sistema nasce com
estes números, para não começar chutando:

| Sinal | 🔴 BUG | 🟡 PROMO |
|---|---|---|
| 1 — desvio da mediana entre lojas | preço ≤ 55% da mediana (45%+ abaixo) | 55% a 80% da mediana |
| 2 — queda contra o próprio histórico | queda ≥ 40% numa única coleta | queda ≥ 20% |
| 3 — posição na curva de R$/GB | nunca sozinho | abaixo do percentil 5 do dia |

O Sinal 1 exige a chave canônica presente em **3 lojas ou mais**; com menos
que isso a mediana não tem sustentação e o sinal é ignorado. O Sinal 3 nunca
gera 🔴 sozinho: ele é fraco por natureza (compara produtos diferentes entre
si) e só serve para levantar suspeita.

Estes números são um ponto de partida deliberadamente conservador. Sem histórico coletado não há como acertar o número
de primeira. A tela de configuração mostra, para o limiar escolhido, quantos
alertas teriam disparado nos últimos 7 dias — a calibração é feita vendo o
efeito, não no escuro.

### Guardas anti-falso-positivo

Uma candidata só vira alerta se passar por todas:

1. **Tem estoque.** Preço de produto indisponível é lixo.
2. **É novo.** Usado e recondicionado saem da comparação — são baratos por
   motivo legítimo.
3. **Kit conferido.** Título sugerindo número de módulos incompatível com a
   capacidade declarada marca a oferta como suspeita: não gera 🔴.
4. **Vendedor com reputação** (marketplace). Vendedor novo ou sem reputação no
   Mercado Livre não gera 🔴 — é o padrão clássico do golpe de preço baixo.
5. **Não repetir.** Mesmo produto, mesma loja, mesmo preço não alerta duas
   vezes; só volta a alertar se o preço cair mais.
6. **Freio de mercado.** Se mais da metade das ofertas da rodada disparariam
   alerta, o motor não alerta nada e registra o evento — isso não é bug de
   preço, é o coletor ou o parser quebrado.

O guarda 6 é o que impede o pior cenário: um erro no parser de capacidade
transformando o catálogo inteiro em "oportunidade" e enterrando o iPhone de
João em notificações às 3h da manhã.

## 9. Notificação

**Telegram é o canal principal.** É um app nativo com push confiável no iPhone,
custa R$ 0, não precisa de Apple Developer Program nem de build, e chega mesmo
com o painel fechado. A mensagem carrega foto, preço, R$/GB, desvio, loja e um
botão que leva direto ao caminho de compra.

**Web Push (VAPID)** é o complemento: com o PWA na tela de início (iOS 16.4+),
tocar na notificação abre o painel já na tela daquele alerta.

Regra de silêncio: 🟡 PROMO respeita horário noturno e vai agrupado numa
mensagem só. 🔴 BUG ignora o silêncio — é o motivo do sistema existir.

## 10. Painel

Quatro telas, protegidas por senha única, servidas pelo FastAPI com Jinja e
HTMX (a lista de alertas se atualiza sozinha por polling, sem recarregar a
página).

1. **Alertas** (inicial) — cartões dos alertas ativos, ordenados por força do
   sinal. Cada cartão: foto, título, preço, R$/GB, "42% abaixo das outras
   lojas", há quanto tempo, e o botão de compra.
2. **Mercado** — todo o DDR5 coletado, ordenável por R$/GB, com filtro de
   capacidade e velocidade. É a tela de quando ele quer comprar sem estar
   caçando bug.
3. **Produto** — histórico de preço de uma chave canônica, uma linha por loja.
   Responde "esse preço é bom mesmo, ou já esteve mais barato?".
4. **Configuração** — sensibilidade dos limiares (com a prévia de quantos
   alertas teriam disparado), lojas ligadas/desligadas, saúde de cada
   adaptador, teste de notificação.

O painel é um PWA: manifesto, service worker e ícones, para ganhar ícone na
tela de início do iPhone e abrir em tela cheia, sem barra de navegador.

## 11. Compra em um toque

```
push do Telegram  →  toca  →  painel abre no alerta  →  [ COMPRAR AGORA ]
                                                              ↓
                     deep link abre o app da loja com o item no carrinho
                                                              ↓
                          Apple Pay / cartão salvo na loja  →  confirma
```

O botão usa o caminho mais curto que cada loja aceita:

| Loja | Destino do botão |
|---|---|
| Amazon | `/gp/aws/cart/add.html?ASIN=…&Quantity.1=1` — cai no carrinho com o item dentro |
| Mercado Livre | Link do produto como universal link, abre o app nativo já logado |
| Kabum | Link do produto (o app captura o link) |
| Pichau / Terabyte | Link do produto no navegador |

**Pré-requisito, feito uma vez por João** — está fora do código, mas é o que
torna a promessa de 15 segundos real:

- Cartão salvo no perfil da Kabum, Pichau, Terabyte, Amazon e Mercado Livre.
- Apps de Amazon e Mercado Livre instalados e logados no iPhone.
- Apple Pay ativo.
- Endereço de entrega padrão definido em cada loja.

Faltando qualquer um, o alerta continua chegando — só que o checkout vira 90
segundos de digitação, e o preço bugado pode não esperar.

## 12. Testes

`pytest`, e a suíte roda sem rede.

- **Parser de título:** o maior conjunto de testes do projeto. Cada título real
  esquisito encontrado na coleta vira um caso fixo com a chave canônica
  esperada. É aqui que a qualidade do sistema inteiro é decidida.
- **Motor de detecção:** cenários montados à mão — o bug óbvio, a promoção
  legítima que não pode virar 🔴, o pente único vendido como kit, o usado
  barato, o vendedor sem reputação, o mercado inteiro disparando (guarda 6).
- **Adaptadores:** testados contra HTML/JSON salvo em arquivo, nunca contra a
  rede. Teste que depende de loja no ar é teste que quebra sozinho no domingo.
- **Um teste de fumaça por loja**, rodado só sob demanda (`pytest -m rede`),
  que bate na loja de verdade e confirma que o formato não mudou. É o alarme de
  "o adaptador apodreceu".

## 13. Limites de conduta

- O sistema **avisa**, não compra. Nenhuma automação de checkout: o clique é
  sempre de João. Bot de compra viola os termos de uso das lojas e derruba
  conta.
- Coleta em ritmo respeitoso, sem burlar autenticação e sem conta falsa.
- Comprar um produto anunciado com preço errado é legítimo — a loja pode
  cancelar a venda, e às vezes cancela. O sistema não promete que a compra vai
  ser honrada.
- Uso pessoal, um comprador, quantidade normal.

## 14. Riscos e caminho de upgrade

| Risco | Mitigação |
|---|---|
| Atraso do cron do GitHub Actions | Aceito no v1. Upgrade: mesmo código Python numa máquina Fly.io (~US$ 3/mês) com cron real de 3 min |
| Amazon servindo captcha | Ritmo baixo; adaptador desliga sozinho após N falhas e o painel mostra |
| Pichau/Terabyte reforçarem o anti-bot | Adaptador isolado desliga sem derrubar o resto; sistema segue com 3 lojas |
| Parser errando capacidade | Guarda 6 (freio de mercado) + suíte de testes de título |
| Alerta demais e João parar de ler | Limiar conservador de partida + calibração com prévia + silêncio noturno para 🟡 |
| Vercel serverless esgotando conexões | Pooler do Supabase na 6543, obrigatório |
| Querer app nativo iOS depois | O FastAPI já é a API; só plugar um cliente. Custo: US$ 99/ano de Apple Developer |

## 15. Ordem de construção

Ordem de camadas de sempre: banco → coleta → normalização → detecção →
notificação → painel → compra.

O schema nasce completo. A primeira entrega útil é o coletor gravando preço no
banco — sem isso não há histórico, e sem histórico o motor de detecção não tem
como ser calibrado. Alertar vem depois de existir uma semana de dados.

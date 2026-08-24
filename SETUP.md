# Ligar o DDR5 Radar

Três coisas, nesta ordem. Sem elas o coletor não roda sozinho e não existe
histórico — e sem histórico o Plano 2 (detecção, alerta, painel) não tem como
ser calibrado.

## 1. Banco no Supabase (5 min)

1. https://supabase.com/dashboard → **New project**
2. Nome `ddr5-radar`, região **South America (São Paulo)**, senha forte
3. Depois de criado: **Project Settings → Database → Connection string → URI**
4. Copiar a string da porta **5432** (conexão direta, não a 6543 do pooler — o
   pooler é pro painel do Plano 2)
5. Trocar o começo de `postgresql://` para `postgresql+psycopg://`

Testar aqui:

```bash
cd ~/ddr5-radar
export DATABASE_URL="postgresql+psycopg://postgres:SENHA@db.PROJETO.supabase.co:5432/postgres"
.venv/bin/alembic upgrade head
.venv/bin/python -m ddr5_radar.cli coletar --loja kabum
```

## 2. App no Mercado Livre (5 min)

É a única loja que hoje não coleta — falta credencial.

1. https://developers.mercadolivre.com.br → entrar com sua conta do ML
2. **Minhas aplicações → Criar aplicação**
3. Nome qualquer; em "URI de redirect" pode pôr `https://localhost` (o fluxo
   usado aqui é `client_credentials`, não precisa de redirect de verdade)
4. Guardar o **App ID** (`ML_CLIENT_ID`) e a **Secret Key** (`ML_CLIENT_SECRET`)

Testar:

```bash
export ML_CLIENT_ID="..."
export ML_CLIENT_SECRET="..."
.venv/bin/python -m ddr5_radar.cli coletar --loja mercadolivre
```

## 3. Repositório público no GitHub (5 min)

**Precisa ser público** — é o que torna o GitHub Actions ilimitado. Não há
segredo no código; tudo sensível vai em Secrets.

```bash
cd ~/ddr5-radar
gh repo create ddr5-radar --public --source=. --push
```

Depois, em **Settings → Secrets and variables → Actions → New repository
secret**, criar os três:

| Nome | Valor |
|---|---|
| `DATABASE_URL` | a string do passo 1 |
| `ML_CLIENT_ID` | do passo 2 |
| `ML_CLIENT_SECRET` | do passo 2 |

Por linha de comando:

```bash
gh secret set DATABASE_URL
gh secret set ML_CLIENT_ID
gh secret set ML_CLIENT_SECRET
```

Então disparar à mão a primeira vez: aba **Actions → coletar → Run workflow**.
Depois disso ele roda sozinho a cada 10 minutos.

## Conferir que está vivo

No SQL Editor do Supabase:

```sql
select loja, count(*) from ofertas group by loja order by 2 desc;

select loja, sucesso, qtd_ofertas, erro
from saude_adaptadores
where rodada_id = (select max(id) from rodadas);

-- o histórico crescendo (deve ser MUITO menor que ofertas × rodadas)
select rodada_id, count(*) from precos group by rodada_id order by rodada_id desc limit 5;
```

Loja com `sucesso = false` tem o motivo escrito em `erro`.

## Quando me chamar de volta

Depois de **uns 7 dias** de coleta rodando. Aí existe histórico real e dá para
escrever o Plano 2 com limiares calibrados em cima do que o mercado fez de
verdade, em vez de número chutado.

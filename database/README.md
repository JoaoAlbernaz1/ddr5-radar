# Banco de dados PartWatch

O banco está **ativo** no Supabase, dentro da organização `PartWatch`, em projeto independente: [abrir SQL Editor](https://supabase.com/dashboard/project/xlmurmfdkkvnalwsbyfa/editor).

A migração `partwatch_initial_schema_rls` foi aplicada ao projeto em 18/11/2026 (UTC 19/11). O arquivo [`bootstrap.sql`](./bootstrap.sql) preserva a definição original. **Não reaplique o bootstrap** em um banco com as tabelas existentes; migrações posteriores precisam de arquivos incrementais.

## Esquema e permissões

| Tabela | Finalidade |
|---|---|
| `parts` | Peças monitoradas e preços-alvo por usuário |
| `price_history` | Histórico coletado pelo worker |
| `alerts` | Alertas gerados quando o worker constata queda |
| `builds` | Montagens salvas por usuário |

Todas as tabelas públicas têm RLS. `anon` não pode ler os dados. Usuários autenticados acessam apenas os próprios registros. Uma conta autenticada pode inserir uma peça com preço inicial e ajustar campos de configuração, mas **não** alterar `current_price` nem criar histórico/alertas; somente o worker privilegiado pode fazê-lo.

A consulta de [`verify.sql`](./verify.sql) foi executada: quatro tabelas com RLS, políticas e grants conferidos. O Security Advisor do projeto não retornou alertas na verificação inicial.

## Flutter e Auth

O aplicativo usa `supabase_flutter: 2.15.4` com a URL e chave publicável do próprio projeto. Essa chave é apropriada para código cliente porque a autorização depende de Auth e RLS. O login agora usa e-mail/senha reais; o cadastro pode exigir confirmação de e-mail no projeto.

- Nenhum dado de demonstração local é automaticamente migrado.
- `SharedPreferences` só é usado para lembrar a conclusão do onboarding.
- Os dados remotos são lidos quando a sessão inicia e mediante atualização manual.
- Ainda faltam testes de fluxo em dispositivo com duas contas reais e validação de operações concorrentes.

## Worker de preços — ativação separada

A chave `service_role` ou equivalente secret **nunca** deve estar no código Flutter, no GitHub público ou em mensagens.

1. Configure `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` nos [Secrets do GitHub Actions](https://github.com/JoaoAlbernaz1/ddr5-radar/settings/secrets/actions), recuperados do projeto PartWatch.
2. Crie uma peça de teste em uma conta autenticada pelo app. Verifique o nome do produto/loja; a busca conservadora do worker exige um único modelo correspondente e não tenta consultar lojas diferentes da KaBuM; resultados ainda exigem validação manual.
3. Rode [Check Prices](https://github.com/JoaoAlbernaz1/ddr5-radar/actions/workflows/check-prices.yml) manualmente, inspecione os produtos retornados e confirme o histórico.
4. Apenas depois de tornar a correspondência de produtos confiável e de confirmar coleta correta, defina `PRICE_CHECK_ENABLED=true` nas Repository Variables do GitHub.

Não compartilhe o banco com UniMove. Não use a chave de serviço para autenticação do app. Nunca confunda um check verde com coleta de preços bem-sucedida.

# Banco de dados do PartWatch (Supabase)

O **PartWatch ainda não possui banco hospedado próprio**. O arquivo [`bootstrap.sql`](./bootstrap.sql) descreve o esquema inicial para um projeto **novo e exclusivo**, separado de qualquer outro aplicativo.

## Estrutura prevista

| Tabela | Finalidade |
|---|---|
| `parts` | Peças monitoradas, dono, preço atual, preço-alvo e configuração de alertas |
| `price_history` | Histórico de preços coletados pelo worker |
| `alerts` | Alertas gerados quando os preços caem |
| `builds` | Resumo das montagens salvas |

Todas as tabelas do schema `public` têm **RLS habilitado**. Cada usuário autenticado só pode acessar os próprios itens. Apenas o processo do servidor, com chave secreta guardada em ambiente privado, deve escrever histórico e alertas. Operações anônimas não recebem permissão.

## Como preparar o projeto

1. Crie um projeto Supabase **novo** chamado `partwatch`, na organização selecionada por você. **Não use o banco do UniMove.** A criação pode ter custo, conforme seu plano.
2. Abra o **SQL Editor** do novo projeto, cole o conteúdo integral de [`bootstrap.sql`](./bootstrap.sql) e execute **uma vez só**. A transação falha se alguma tabela já existir para não encobrir conflitos de estrutura.
3. Use [`verify.sql`](./verify.sql) para consultar se as quatro tabelas possuem RLS e se os papéis públicos não têm acesso amplo.
4. Configure o Supabase Auth (usuários de teste, e-mail/senha e as opções de sessão adequadas). O formulário atual do aplicativo é **mock**: não autentica usuários de verdade.
5. Em [GitHub Actions Secrets](https://github.com/JoaoAlbernaz1/ddr5-radar/settings/secrets/actions), configure `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` **somente para o worker**. A chave secreta **nunca** deve ser incluída no Flutter.
6. Quando houver uma tabela `parts` populada com dados válidos, execute o [Check Prices](https://github.com/JoaoAlbernaz1/ddr5-radar/actions/workflows/check-prices.yml) manualmente. Observe os logs para identificar bloqueios da loja, consultas vazias e falhas de escrita.
7. Só depois de validar o worker defina a variável `PRICE_CHECK_ENABLED=true` no repositório para habilitar os agendamentos.

## O que ainda falta implementar

O app Flutter atual persiste seus dados em `SharedPreferences`, enquanto o script Python lê e escreve no Supabase. O banco **não conecta essas duas partes sozinho**. Antes de chamar o PartWatch de funcional com dados reais, falta:

- Substituir o formulário de login fictício por **Supabase Auth**.
- Criar uma camada de persistência remota na aplicação com o client Flutter e **chave publicável**, usando RLS; migrar dados locais de forma deliberada.
- Sincronizar a lista do app com `parts`, `price_history` e `alerts`, além de corrigir tratamento de erros, estados offline e conflitos.
- Rever a associação de resultados da KaBuM com o produto exato antes de atualizar preços: atualmente o scraper escolhe o primeiro produto disponível e pode associar uma oferta diferente à peça.
- Validar políticas de acesso com **dois usuários diferentes** e um usuário anônimo, inclusive tentativas cruzadas de leitura/escrita.
- Revisar as consultas de preços e observabilidade para detectar casos em que o scraper roda mas nenhum produto é encontrado.

### Segurança

- A chave `service_role` ignora RLS: **somente no GitHub Actions / servidor de confiança**.
- Use uma **chave publicável** na aplicação Flutter após implementar autenticação e autorização por RLS.
- Não cole credenciais em issues, commits ou mensagens.
- O SQL é um ponto de partida para um projeto novo, não uma migração já aplicada a um banco existente.

Referência: https://supabase.com/docs/guides/database/postgres/row-level-security

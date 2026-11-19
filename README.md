# PartWatch

Radar de preço de peças de PC — monitore peças, compare preço entre lojas,
monte builds e receba alerta quando o preço cair. Projeto pessoal, substitui
o antigo `ddr5-radar` (que só cobria DDR5 via scraper Python) por um app
completo com interface.

Identidade visual "Dark Radar" — fundo `#0A0D12`, acento verde neon `#37FF8B`,
violeta `#8B5CF6` pra alertas de meta, Space Grotesk (títulos) + JetBrains
Mono (dados/preços) + Inter (corpo). Portado do protótipo gerado no Figma
Make (`figma.com/make/vOAkGkBz3ps9PUjTlmJqcK`) — mesma paleta e tipografia,
incluindo o orbe de radar animado e o scanline no fundo das telas.

## Telas

1. **Onboarding** — 3 slides de introdução ao app
2. **Login / Cadastro** — Supabase Auth real, com confirmação de e-mail quando exigida
3. **Minha Wishlist** (Radar) — lista de peças monitoradas, resumo de economia potencial
4. **Buscar Peças** — filtro das peças cadastradas na conta; catálogo externo ainda não integrado
5. **Valor registrado** — preço informado/capturado; comparador multi-loja indisponível
6. **Adicionar Peça** — formulário com seletor de categoria e banner de scan
7. **Detalhe da Peça** — preço + histórico com linha de alvo, toggle de notificação
8. **Minhas Builds** — montagens salvas com custo total e aviso de compatibilidade
9. **Alertas** — linha do tempo de notificações (queda de preço, voltou ao estoque, atingiu o alvo)
10. **Perfil** — conta, preferências, sair

## Banco de dados Supabase

O PartWatch tem um projeto independente no Supabase, na organização **PartWatch**, sem compartilhamento de dados com o UniMove. [Abrir o projeto](https://supabase.com/dashboard/project/xlmurmfdkkvnalwsbyfa/editor).

A migração `partwatch_initial_schema_rls` foi aplicada: `parts`, `price_history`, `alerts` e `builds`, com RLS e políticas por usuário. [Esquema e verificações](database/README.md).

A aplicação agora usa **Supabase Auth e dados remotos**. O SDK utiliza a chave **publicável** do projeto, que pode ser distribuída ao cliente e está sujeita à RLS. **Nunca** embuta a chave `service_role` no Flutter.

## Como rodar

1. Instale o Flutter: https://docs.flutter.dev/get-started/install/windows
   (baixe o zip, extraia, adicione `flutter\bin` ao PATH)
2. Confirme a instalação: `flutter doctor`
3. Dentro desta pasta, gere as pastas de plataforma (Android/iOS/etc, que
   ainda não existem neste projeto):
   ```
   flutter create .
   ```
   Isso não mexe no `lib/` nem no `pubspec.yaml` já existentes — só adiciona
   o que falta.
4. Instale as dependências:
   ```
   flutter pub get
   ```
5. Rode num emulador Android ou dispositivo conectado:
   ```
   flutter run
   ```

## GitHub Actions: CI Flutter e monitoramento de preços

O repositório tem **dois workflows independentes**:

- [Flutter CI](.github/workflows/flutter-ci.yml): roda `flutter pub get`, análise estática e testes. Arquivos Dart novos ou modificados devem estar formatados com `dart format`; arquivos antigos com formatação pendente não bloqueiam alterações só de configuração. A análise continua bloqueando **erros e warnings**, mas os 13 avisos informativos já existentes sobre `const` não bloqueiam o CI (`flutter analyze --no-fatal-infos`).
- [Check Prices](.github/workflows/check-prices.yml): scraper Python de preços da KaBuM com gravação no Supabase. **A agenda automática começa desativada enquanto não for configurada.** Isso evita que a execução continue falhando indefinidamente por falta de credenciais.

### Habilitar a coleta de preços no GitHub

1. No repositório, abra **Settings → Secrets and variables → Actions → Secrets** e adicione os dois **Repository secrets**:
   - `SUPABASE_URL`: a URL do projeto correto, por exemplo `https://<project-ref>.supabase.co`.
   - `SUPABASE_SERVICE_ROLE_KEY`: chave de acesso **privilegiada** do mesmo projeto (somente em Secrets, nunca em código, README, logs ou `VITE_`/`EXPO_PUBLIC_`).
2. Abra **Actions → Check Prices → Run workflow**, na branch `master`. Se faltar uma credencial, a execução exibirá o nome dela sem imprimir seu valor. Se as credenciais existirem, realizará uma coleta real.
3. **Somente depois de confirmar uma execução manual bem-sucedida**, vá em **Settings → Secrets and variables → Actions → Variables** e crie o *Repository variable* `PRICE_CHECK_ENABLED` com valor `true`. Isso libera as execuções agendadas, configuradas para cada 30 minutos (o GitHub pode atrasá-las).
4. Para pausar a rotina, mude `PRICE_CHECK_ENABLED` para `false` ou remova a variável. As execuções agendadas ficarão com o job marcado como *skipped*, não como uma coleta bem-sucedida.

**Importante:** ter o job verde significa que o código executou, **não** que a loja entregou preços ou que as informações estão chegando ao aplicativo. O scraper depende das tabelas `parts`, `price_history` e `alerts` com a estrutura esperada e da disponibilidade da KaBuM; a loja pode bloquear a requisição ou alterar o HTML.

### O que o aplicativo já usa do banco

A lista de peças, builds, histórico e alertas vêm do Supabase. A autenticação é real (e-mail/senha), e cada usuário só pode ler suas próprias informações por RLS. O onboarding usa `SharedPreferences` apenas para guardar que já foi visto; dados antigos locais não são enviados automaticamente.

**Limitações:** o botão na wishlist recarrega os dados, mas o app não tem atualização em tempo real/push. O feed só mostrará alertas depois de uma coleta válida pelo worker. A busca lista apenas as peças cadastradas na conta. O comparador com lojas externas foi substituído por um aviso honesto: ainda não existe uma API de cotações confiável. O Google Login não está habilitado. Não há garantia de correspondência entre o primeiro resultado da KaBuM e a peça correta: validar o matcher antes de ligar o agendamento.

Para verificar o scraper sem rede ou segredos:

```bash
python -m pip install -r scraper/requirements.txt
python -m unittest discover -s scraper/tests -v
```

## Estado atual

- Supabase Auth por e-mail/senha; contas não confirmadas aguardam o e-mail.
- CRUD de peças e builds e leitura de histórico/alertas no Supabase com RLS.
- Botão de atualização consulta o banco, **não** simula queda de preço.
- Conta de demonstração e dados locais fictícios removidos como fonte principal.
- CI Flutter (format/analyze/tests), testes do scraper e `pubspec.lock` versionado.
- Coleta automática de preços ainda **desativada**. O GitHub precisa de Secrets privados e teste real do scraper.

## Próximas etapas

- Cadastrar um usuário pelo app e confirmar e-mail, se necessário, para validar o fluxo no dispositivo real.
- Configurar os Secrets no GitHub e testar o worker com uma peça real cuidadosamente conferida.
- Evitar correspondência aproximada insegura de produtos na KaBuM: usar identificadores/URLs de produto e validações antes de publicar preços.
- Substituir ofertas sintéticas do comparador por registros reais e auditáveis.
- Implementar refresh automático em primeiro plano, sincronização offline e notificações push quando houver dados confiáveis.

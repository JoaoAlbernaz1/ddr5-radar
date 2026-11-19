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
2. **Login / Cadastro** — autenticação (mock por enquanto)
3. **Minha Wishlist** (Radar) — lista de peças monitoradas, resumo de economia potencial
4. **Buscar Peças** — catálogo com chips de categoria e filtro em bottom sheet
5. **Ofertas** — comparador de preço entre lojas pra uma peça
6. **Adicionar Peça** — formulário com seletor de categoria e banner de scan
7. **Detalhe da Peça** — preço + histórico com linha de alvo, toggle de notificação
8. **Minhas Builds** — montagens salvas com custo total e aviso de compatibilidade
9. **Alertas** — linha do tempo de notificações (queda de preço, voltou ao estoque, atingiu o alvo)
10. **Perfil** — conta, preferências, sair

## Banco de dados (ainda não provisionado)

O PartWatch **não tem banco de dados Supabase próprio criado**. O [esquema inicial e os passos de configuração](database/README.md) estão preparados para um projeto novo e separado. A aplicação Flutter segue usando dados locais, e a coleta remota permanecerá desativada até existir um banco configurado, o Supabase Auth estar implementado e a integração ser validada. **Não reutilize o banco do UniMove.**

## Como rodar (esta máquina ainda não tem o Flutter SDK instalado)

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

### Limite atual do aplicativo

O app Flutter ainda usa `SharedPreferences` e dados locais para a lista de peças, enquanto o scraper Python lê e escreve dados remotos no Supabase. **Essas duas fontes não estão integradas.** Configurar Secrets resolverá a autenticação do workflow, mas **não fará os preços aparecerem automaticamente na tela do app**. Isso depende de uma implementação separada e testes de integração seguros com o backend; nunca incorpore a service-role key no app.

Para verificar o scraper sem rede ou segredos:

```bash
python -m pip install -r scraper/requirements.txt
python -m unittest discover -s scraper/tests -v
```

## Estado atual

- UI completa e funcional, com dados de exemplo pré-carregados
- Persistência local via `SharedPreferences` (os dados sobrevivem a reabrir o app)
- Botão "🧪 Simular queda de preço" na tela de Detalhe pra testar o fluxo de
  alerta sem precisar de busca real ainda

## Próximos passos (fora do escopo de hoje)

- Trocar a simulação por uma busca real de preço por loja (scraper ou API),
  reaproveitando a lógica que já existia no `ddr5-radar`
- Rodar essa busca em background (ex: `WorkManager`/`workmanager` package)
  periodicamente
- Notificação push de verdade via `flutter_local_notifications` quando o
  preço atingir o alvo

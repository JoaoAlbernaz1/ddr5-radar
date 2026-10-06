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

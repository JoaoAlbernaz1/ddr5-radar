import 'package:flutter_test/flutter_test.dart';
import 'package:partwatch/theme/app_theme.dart';

// Smoke test só pra garantir que o pacote compila e o CI tem algo pra
// rodar. Evita propositalmente montar a árvore de widgets completa aqui
// (teria que bater na rede pra buscar fontes do Google Fonts e as fotos
// via Image.network, o que deixaria o teste lento e instável).
void main() {
  test('paleta de cores está definida', () {
    expect(AppColors.bg, isNotNull);
    expect(AppColors.green, isNotNull);
  });
}

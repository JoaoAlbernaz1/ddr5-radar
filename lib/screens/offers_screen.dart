import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/part.dart';
import '../theme/app_theme.dart';
import '../widgets/part_photo.dart';
import '../widgets/topbar.dart';

/// Displays recorded information, never synthetic third-party offers.
class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key, required this.part});

  final Part part;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final collected = part.history.isNotEmpty;
    final description = collected
        ? 'Último valor registrado pelo coletor. A consulta não é em tempo '
            'real e o produto precisa ser conferido antes da compra.'
        : 'Preço inicial informado no cadastro desta peça. Ainda não '
            'há registros de coleta da loja.';

    return Scaffold(
      appBar: TopBar(
        title: 'Valor registrado',
        eyebrow: 'SEM COTAÇÃO AO VIVO',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                PartPhoto(category: part.category, size: 90),
                const SizedBox(height: 12),
                Text(
                  part.name,
                  style: AppText.cardTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(part.store, style: AppText.monoSmall),
                const SizedBox(height: 22),
                Text(currency.format(part.currentPrice), style: AppText.priceLg),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: AppText.body,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              'A comparação entre KaBuM, Pichau, Amazon e Terabyte está '
              'indisponível até o projeto integrar ofertas reais. '
              'Não exibimos preços ou prazos de entrega fictícios.',
              style: AppText.body,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/parts_repository.dart';
import '../models/offer.dart';
import '../models/part.dart';
import '../theme/app_theme.dart';
import '../widgets/part_photo.dart';
import '../widgets/topbar.dart';

/// Comparador de preço entre lojas pra uma peça — gerado a partir do
/// preço base, igual ao protótipo web (até termos um scraper de verdade).
class OffersScreen extends StatelessWidget {
  final Part part;
  const OffersScreen({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final offers = buildOffersFor(part.currentPrice);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: TopBar(title: 'Ofertas', eyebrow: '${offers.length} LOJAS ENCONTRADAS', onBack: () => Navigator.of(context).pop()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.line)),
            child: Row(
              children: [
                PartPhoto(category: part.category, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(part.category, style: AppText.monoSmall.copyWith(color: AppColors.green, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(part.name, style: AppText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Preços atualizados há 4 min', style: AppText.monoSmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.greenSoft, AppColors.surface]),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.green.withOpacity(0.14)),
            ),
            child: Column(
              children: [
                Text('MENOR PREÇO', style: AppText.monoSmall.copyWith(color: AppColors.muted)),
                const SizedBox(height: 8),
                Text(currency.format(offers.first.price), style: AppText.priceLg.copyWith(fontSize: 24)),
                const SizedBox(height: 6),
                Text('↓ ${(part.deltaPercent ?? 0).abs().toStringAsFixed(1)}% esta semana', style: AppText.mono.copyWith(color: AppColors.green)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(offers.length, (i) {
            final offer = offers[i];
            final best = i == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(12, best ? 18 : 14, 12, 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: best ? AppColors.green.withOpacity(0.35) : AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(offer.store, style: AppText.cardTitle.copyWith(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('Em estoque', style: AppText.monoSmall),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currency.format(offer.price), style: AppText.price.copyWith(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(offer.shipping, style: AppText.monoSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final repo = context.read<PartsRepository>();
                            if (repo.partById(part.id) == null) {
                              await repo.addPart(
                                name: part.name,
                                category: part.category,
                                store: offer.store,
                                currentPrice: offer.price,
                                targetPrice: part.targetPrice > 0 ? part.targetPrice : offer.price * 0.9,
                              );
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicionado à Wishlist!')));
                              Navigator.of(context).pop();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.green,
                            side: BorderSide(color: AppColors.green.withOpacity(0.3)),
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Monitorar', style: AppText.mono.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.green)),
                        ),
                      ],
                    ),
                  ),
                  if (best)
                    Positioned(
                      top: -1,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(5), bottomRight: Radius.circular(5)),
                        ),
                        child: Text('MELHOR PREÇO', style: AppText.monoSmall.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/part.dart';
import '../theme/app_theme.dart';
import 'part_photo.dart';

/// Card de peça da Wishlist: foto, categoria+loja, nome, preço+variação
/// e uma barrinha de progresso até o preço alvo — espelha o `.part-card`
/// do protótipo web.
class PartCard extends StatelessWidget {
  final Part part;
  final VoidCallback onTap;

  const PartCard({super.key, required this.part, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final delta = part.deltaPercent;
    final isUp = (delta ?? 0) > 0;
    final deltaColor = isUp ? AppColors.danger : AppColors.green;
    final deltaText = delta == null ? '—' : '${isUp ? '↑' : '↓'} ${delta.abs().toStringAsFixed(1)}%';
    final progress = part.currentPrice <= 0
        ? 0.12
        : (part.targetPrice / part.currentPrice).clamp(0.12, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PartPhoto(category: part.category, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(5)),
                          child: Text(part.category, style: AppText.monoSmall.copyWith(color: AppColors.green, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(part.store, style: AppText.monoSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(part.name, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(currency.format(part.currentPrice), style: AppText.price),
                        Text(deltaText, style: AppText.mono.copyWith(color: deltaColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: AppColors.line,
                        valueColor: const AlwaysStoppedAnimation(AppColors.green),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('ALVO ${currency.format(part.targetPrice)}', style: AppText.monoSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

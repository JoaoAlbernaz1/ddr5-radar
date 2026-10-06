import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/parts_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/part_card.dart';
import '../widgets/radar_orb.dart';
import '../widgets/topbar.dart';
import 'part_detail_screen.dart';

class WishlistScreen extends StatelessWidget {
  final VoidCallback onAddPressed;

  const WishlistScreen({super.key, required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PartsRepository>();
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    if (!repo.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.green)));
    }

    final parts = repo.parts;
    final potentialSavings = parts.fold<double>(0, (sum, p) => sum + (p.currentPrice - p.targetPrice).clamp(0, double.infinity));
    final best = parts.isEmpty
        ? null
        : parts.reduce((a, b) => (a.deltaPercent ?? 0) < (b.deltaPercent ?? 0) ? a : b);

    return Scaffold(
      appBar: TopBar(
        action: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.green.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('RADAR ATIVO', style: AppText.monoSmall.copyWith(color: AppColors.green, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CENTRAL DE MONITORAMENTO', style: AppText.eyebrow),
                    const SizedBox(height: 6),
                    Text('Minha wishlist', style: AppText.h1),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: AppText.body,
                        children: [
                          TextSpan(text: '${parts.length} peças', style: AppText.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600)),
                          const TextSpan(text: ' sob vigilância em tempo real.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const RadarOrb(size: 92),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _SummaryCard(
                  icon: AppIconName.activity,
                  label: 'ECONOMIA POTENCIAL',
                  value: currency.format(potentialSavings),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _SummaryCard(
                  icon: AppIconName.zap,
                  label: 'MELHOR QUEDA',
                  value: best == null ? '—' : '${(best.deltaPercent ?? 0).toStringAsFixed(1)}%',
                  valueColor: AppColors.green,
                  caption: best?.name,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ITENS MONITORADOS', style: AppText.mono.copyWith(fontWeight: FontWeight.w600, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text('Atualizado agora', style: AppText.monoSmall),
                ],
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Center(child: AppIcon(AppIconName.settings, size: 15, color: AppColors.text)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (parts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Nenhuma peça monitorada ainda.',
                  style: AppText.body,
                ),
              ),
            )
          else
            ...parts.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PartCard(
                  part: p,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PartDetailScreen(partId: p.id)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddPressed,
              icon: const AppIcon(AppIconName.plus, size: 16, color: AppColors.onAccent),
              label: Text('Adicionar peça', style: AppText.title.copyWith(color: AppColors.onAccent, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AppIconName icon;
  final String label;
  final String value;
  final Color? valueColor;
  final String? caption;

  const _SummaryCard({required this.icon, required this.label, required this.value, this.valueColor, this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.surfaceAlt, AppColors.surface]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Expanded(child: Text(label, style: AppText.monoSmall.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: AppText.price.copyWith(fontSize: 17, color: valueColor ?? AppColors.text)),
          const SizedBox(height: 4),
          Text(caption ?? 'Se todos atingirem o alvo', style: AppText.monoSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/parts_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import '../widgets/part_photo.dart';
import '../widgets/topbar.dart';

class PartDetailScreen extends StatefulWidget {
  final String partId;
  const PartDetailScreen({super.key, required this.partId});

  @override
  State<PartDetailScreen> createState() => _PartDetailScreenState();
}

class _PartDetailScreenState extends State<PartDetailScreen> {
  bool _notify = true;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PartsRepository>();
    final part = repo.partById(widget.partId);
    if (part == null) {
      return const Scaffold(body: Center(child: Text('Peça não encontrada.')));
    }
    if (!_initialized) {
      _notify = part.notifyOnDrop;
      _initialized = true;
    }

    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final delta = part.deltaPercent ?? 0;
    final history = part.history.length >= 2
        ? part.history.sublist(part.history.length > 6 ? part.history.length - 6 : 0)
        : part.history;
    final prices = history.map((h) => h.price).toList();
    final minP = prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b);
    final maxP = prices.isEmpty ? 1 : prices.reduce((a, b) => a > b ? a : b);
    final range = (maxP - minP).abs() < 0.01 ? 1 : maxP - minP;
    final targetFrac = ((part.targetPrice - minP) / range).clamp(0.0, 1.0);

    return Scaffold(
      appBar: TopBar(
        title: 'Detalhes da peça',
        eyebrow: 'MONITOR #PW-${part.id.hashCode.toUnsigned(12)}',
        onBack: () => Navigator.of(context).pop(),
        action: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.line)),
          child: const Center(child: AppIcon(AppIconName.edit, size: 15, color: AppColors.text)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.green.withOpacity(0.07), AppColors.surface]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(5)),
                    child: Text(part.category, style: AppText.monoSmall.copyWith(color: AppColors.green, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                PartPhoto(category: part.category, size: 110, borderRadius: BorderRadius.circular(16)),
                const SizedBox(height: 10),
                Text('${part.store} • Em estoque', style: AppText.mono.copyWith(fontSize: 10)),
                const SizedBox(height: 6),
                Text(part.name, style: AppText.h2.copyWith(fontSize: 19), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(currency.format(part.currentPrice), style: AppText.priceLg),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(6)),
                      child: Text('${delta <= 0 ? '↓' : '↑'} ${delta.abs().toStringAsFixed(1)}%', style: AppText.mono.copyWith(color: AppColors.green, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('MENOR PREÇO DOS ÚLTIMOS 30 DIAS', style: AppText.monoSmall),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lineSoft)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HISTÓRICO DE PREÇO', style: AppText.monoSmall.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text('Últimas ${history.length} leituras', style: AppText.cardTitle.copyWith(fontSize: 13)),
                      ],
                    ),
                    Row(
                      children: [
                        Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('AO VIVO', style: AppText.monoSmall.copyWith(color: AppColors.green)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 110,
                  child: Stack(
                    children: [
                      if (history.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 20 + targetFrac * 72,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(height: 1, decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.purple.withOpacity(0.45), width: 1)))),
                              ),
                              const SizedBox(width: 4),
                              Text('ALVO', style: AppText.monoSmall.copyWith(color: AppColors.purple)),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(history.length, (i) {
                            final h = (((prices[i] - minP) / range) * 72).clamp(10.0, 90.0);
                            final isLast = i == history.length - 1;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: h,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                        gradient: isLast
                                            ? const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.greenDeep, AppColors.green])
                                            : null,
                                        color: isLast ? null : const Color(0xFF293343),
                                        boxShadow: isLast ? [BoxShadow(color: AppColors.green.withOpacity(0.25), blurRadius: 10)] : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lineSoft)),
            child: Column(
              children: [
                _MonitorRow(
                  icon: AppIconName.target,
                  iconColor: AppColors.green,
                  label: 'PREÇO ALVO',
                  value: currency.format(part.targetPrice),
                  trailing: TextButton(onPressed: () {}, child: Text('Editar', style: AppText.mono.copyWith(color: AppColors.green, fontWeight: FontWeight.w600))),
                ),
                const Divider(height: 1, color: AppColors.lineSoft),
                _MonitorRow(
                  icon: AppIconName.bell,
                  iconColor: AppColors.purple,
                  label: 'NOTIFICAÇÕES',
                  value: _notify ? 'Alertas ativados' : 'Alertas pausados',
                  trailing: Switch(
                    value: _notify,
                    onChanged: (v) async {
                      setState(() => _notify = v);
                      final updated = part..notifyOnDrop = v;
                      await context.read<PartsRepository>().updatePart(updated);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 13,
                child: AppButton(label: 'Salvar', icon: AppIconName.edit, variant: AppButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 10,
                child: AppButton(
                  label: 'Remover',
                  icon: AppIconName.trash,
                  variant: AppButtonVariant.danger,
                  onPressed: () async {
                    await context.read<PartsRepository>().removePart(part.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: () async {
                await context.read<PartsRepository>().simulatePriceCheck(part.id, double.parse((part.currentPrice * 0.95).toStringAsFixed(2)));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preço simulado — confira em Alertas')));
                }
              },
              child: Text('🧪 Simular queda de preço (teste)', style: AppText.body.copyWith(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitorRow extends StatelessWidget {
  final AppIconName icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget trailing;

  const _MonitorRow({required this.icon, required this.iconColor, required this.label, required this.value, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
            child: Center(child: AppIcon(icon, size: 16, color: iconColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.monoSmall.copyWith(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(value, style: AppText.cardTitle.copyWith(fontSize: 13)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

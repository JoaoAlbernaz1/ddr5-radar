import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/parts_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/topbar.dart';

class BuildsScreen extends StatelessWidget {
  const BuildsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PartsRepository>();
    final builds = repo.builds;
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: TopBar(
        title: 'Minhas Builds',
        eyebrow: 'CONFIGURAÇÕES SALVAS',
        action: InkWell(
          onTap: () => _promptNewBuild(context),
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(100)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(AppIconName.plus, size: 13, color: AppColors.onAccent),
                const SizedBox(width: 4),
                Text('Nova Build', style: AppText.mono.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onAccent)),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.purpleSoft, AppColors.surface]),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.purple.withOpacity(0.16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.purpleSoft, borderRadius: BorderRadius.circular(11)),
                  child: const Center(child: AppIcon(AppIconName.box, size: 19, color: AppColors.purple)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${builds.length} builds ativas', style: AppText.cardTitle.copyWith(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Compare o custo total e a compatibilidade.', style: AppText.body, maxLines: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(builds.length, (i) {
            final b = builds[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text('0${i + 1}', style: AppText.mono.copyWith(color: AppColors.mutedDark, fontWeight: FontWeight.w600)),
                    ),
                    Container(width: 1, height: 44, color: AppColors.line, margin: const EdgeInsets.only(right: 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BUILD PERSONALIZADA', style: AppText.monoSmall.copyWith(color: AppColors.green, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(b.name, style: AppText.cardTitle.copyWith(fontSize: 14)),
                          const SizedBox(height: 6),
                          Text(currency.format(b.price), style: AppText.price.copyWith(fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(5)),
                                child: Text('${b.pieces} peças', style: AppText.monoSmall),
                              ),
                              if (b.hasCompatibilityWarning)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(5)),
                                  child: Text('⚠ Verificar compatibilidade', style: AppText.monoSmall.copyWith(color: AppColors.amber)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(5)),
                                  child: Text('COMPATÍVEL', style: AppText.monoSmall.copyWith(color: AppColors.green)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const AppIcon(AppIconName.arrow, rotate180: true, size: 16, color: AppColors.mutedDark),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _promptNewBuild(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Nova build', style: AppText.cardTitle),
        content: TextField(
          controller: ctrl,
          style: AppText.label,
          decoration: InputDecoration(hintText: 'Nome da build', hintStyle: AppText.label.copyWith(color: AppColors.mutedDark)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('Cancelar', style: AppText.body)),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await context.read<PartsRepository>().addBuild(ctrl.text.trim());
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Text('Criar', style: AppText.body.copyWith(color: AppColors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

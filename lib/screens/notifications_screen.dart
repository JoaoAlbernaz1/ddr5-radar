import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/parts_repository.dart';
import '../theme/app_theme.dart';
import '../utils/relative_time.dart';
import '../widgets/app_icon.dart';
import '../widgets/topbar.dart';
import 'part_detail_screen.dart';

const _alertIconCycle = [
  (AppIconName.activity, AppColors.green),
  (AppIconName.target, AppColors.purple),
  (AppIconName.box, AppColors.purple),
  (AppIconName.zap, AppColors.green),
];

/// Feed de alertas — linha do tempo com ícone + mensagem, igual ao
/// `.timeline` do protótipo web.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PartsRepository>();
    final alerts = repo.alerts;
    final newCount = alerts.where((a) => a.date.isAfter(DateTime.now().subtract(const Duration(days: 2)))).length;

    return Scaffold(
      appBar: TopBar(
        title: 'Alertas',
        eyebrow: 'FEED DE SINAIS',
        action: TextButton(onPressed: () {}, child: Text('Ler tudo', style: AppText.mono.copyWith(color: AppColors.green, fontWeight: FontWeight.w600))),
      ),
      body: alerts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Nenhum alerta ainda.\nVocê será avisado quando o preço de uma peça cair.', textAlign: TextAlign.center, style: AppText.body),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.purpleSoft, AppColors.surface]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.purple.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(color: AppColors.purpleSoft, shape: BoxShape.circle),
                            child: const Center(child: AppIcon(AppIconName.bell, size: 21, color: AppColors.purple)),
                          ),
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(width: 11, height: 11, decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2))),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$newCount novos sinais', style: AppText.cardTitle.copyWith(fontSize: 14)),
                            const SizedBox(height: 3),
                            Text('Seu radar encontrou movimentações.', style: AppText.body),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(alerts.length, (i) {
                  final a = alerts[i];
                  final unread = i < 2;
                  final (icon, tone) = _alertIconCycle[i % _alertIconCycle.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: tone.withOpacity(0.2)),
                          ),
                          child: Center(child: AppIcon(icon, size: 18, color: tone)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (repo.partById(a.partId) == null) return;
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartDetailScreen(partId: a.partId)));
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatRelativeTime(a.date).toUpperCase(), style: AppText.monoSmall),
                                const SizedBox(height: 5),
                                Text(a.message, style: AppText.cardTitle.copyWith(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.5), blurRadius: 6)]),
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

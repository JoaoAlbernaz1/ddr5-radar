import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/topbar.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final items = [
      (AppIconName.bell, 'Notificações', AppColors.purple),
      (AppIconName.box, 'Lojas preferidas', AppColors.green),
      (AppIconName.settings, 'Tema', AppColors.blue),
      (AppIconName.radar, 'Sobre o app', AppColors.purple),
    ];

    return Scaffold(
      appBar: const TopBar(title: 'Perfil', eyebrow: 'CONTA DO OPERADOR'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.surfaceAlt, AppColors.surface]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle, border: Border.all(color: AppColors.green.withOpacity(0.25))),
                      alignment: Alignment.center,
                      child: Text('MB', style: AppText.mono.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.green)),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 2,
                      child: Container(width: 11, height: 11, decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 2))),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Marcos Batista', style: AppText.cardTitle.copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('marcos@email.com', style: AppText.body),
                      const SizedBox(height: 4),
                      Text('CONTA ATIVA', style: AppText.monoSmall.copyWith(color: AppColors.green)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text('PREFERÊNCIAS', style: AppText.monoSmall.copyWith(color: AppColors.muted)),
          ),
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
            child: Column(
              children: List.generate(items.length, (i) {
                final (icon, label, color) = items[i];
                return Column(
                  children: [
                    InkWell(
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                              child: Center(child: AppIcon(icon, size: 16, color: color)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(label, style: AppText.label)),
                            const AppIcon(AppIconName.arrow, rotate180: true, size: 16, color: AppColors.mutedDark),
                          ],
                        ),
                      ),
                    ),
                    if (i < items.length - 1) const Divider(height: 1, color: AppColors.lineSoft),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onLogout,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.danger.withOpacity(0.16))),
              child: Row(
                children: [
                  const AppIcon(AppIconName.arrow, size: 17, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Text('Sair da conta', style: AppText.label.copyWith(color: AppColors.danger)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text('PartWatch operando normalmente', style: AppText.body.copyWith(fontSize: 11))),
                Text('V1.0.0', style: AppText.monoSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

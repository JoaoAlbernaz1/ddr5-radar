import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/topbar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Conta sem e-mail';
    final metadataName = user?.userMetadata?['full_name'];
    final name = metadataName is String && metadataName.trim().isNotEmpty
        ? metadataName.trim()
        : email.split('@').first;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Scaffold(
      appBar: const TopBar(
        title: 'Perfil',
        eyebrow: 'CONTA DO OPERADOR',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.surfaceAlt, AppColors.surface],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.greenSoft,
                  child: Text(
                    initial,
                    style: AppText.cardTitle.copyWith(color: AppColors.green),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppText.cardTitle),
                      const SizedBox(height: 4),
                      Text(email, style: AppText.body),
                      const SizedBox(height: 4),
                      Text(
                        'SESSÃO AUTENTICADA',
                        style: AppText.monoSmall.copyWith(
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('SOBRE O MONITORAMENTO', style: AppText.monoSmall),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              'Suas peças e alertas são sincronizados com o Supabase. '
              'A coleta de preços é feita separadamente pelo worker no '
              'GitHub Actions, quando configurado e ativado.',
              style: AppText.body,
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: onLogout,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.danger.withOpacity(0.16),
                ),
              ),
              child: Row(
                children: [
                  const AppIcon(
                    AppIconName.arrow,
                    size: 17,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sair da conta',
                    style: AppText.label.copyWith(color: AppColors.danger),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

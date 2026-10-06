import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'logo.dart';

/// Cabeçalho padrão das telas internas: logomarca (ou botão de voltar) à
/// esquerda, título+eyebrow centralizados opcionais, ação à direita.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? eyebrow;
  final VoidCallback? onBack;
  final Widget? action;

  const TopBar({super.key, this.title, this.eyebrow, this.onBack, this.action});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: onBack != null
                    ? _IconCircleButton(icon: AppIconName.arrow, onTap: onBack!)
                    : const PartWatchLogo(),
              ),
              if (title != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (eyebrow != null) Text(eyebrow!, style: AppText.eyebrow),
                    const SizedBox(height: 3),
                    Text(title!, style: AppText.title.copyWith(fontSize: 15)),
                  ],
                ),
              if (action != null) Align(alignment: Alignment.centerRight, child: action),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final AppIconName icon;
  final VoidCallback onTap;
  const _IconCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(width: 38, height: 38, child: Center(child: AppIcon(icon, size: 16, color: AppColors.text))),
      ),
    );
  }
}

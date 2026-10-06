import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

enum AppButtonVariant { primary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final AppIconName? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    final Border? border;
    final List<BoxShadow>? shadow;
    switch (variant) {
      case AppButtonVariant.primary:
        fg = AppColors.onAccent;
        bg = AppColors.green;
        border = null;
        shadow = [BoxShadow(color: AppColors.green.withOpacity(0.18), blurRadius: 24)];
        break;
      case AppButtonVariant.ghost:
        fg = AppColors.text;
        bg = AppColors.surfaceAlt;
        border = Border.all(color: AppColors.line);
        shadow = null;
        break;
      case AppButtonVariant.danger:
        fg = AppColors.danger;
        bg = AppColors.dangerSoft;
        border = Border.all(color: AppColors.danger.withOpacity(0.22));
        shadow = null;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: border,
            boxShadow: shadow,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(icon!, size: 17, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppText.title.copyWith(color: fg, fontSize: 13, letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

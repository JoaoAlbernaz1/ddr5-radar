import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

class PartWatchLogo extends StatelessWidget {
  final double iconSize;
  const PartWatchLogo({super.key, this.iconSize = 24});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.45), blurRadius: 8)],
          ),
          child: AppIcon(AppIconName.radar, size: iconSize, color: AppColors.green),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            style: AppText.mono.copyWith(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.text),
            children: [
              const TextSpan(text: 'PART'),
              TextSpan(text: 'WATCH', style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

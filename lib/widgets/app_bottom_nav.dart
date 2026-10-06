import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showAlertDot;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap, this.showAlertDot = false});

  static const _items = [
    ('Radar', AppIconName.bookmark),
    ('Buscar', AppIconName.search),
    ('Builds', AppIconName.box),
    ('Alertas', AppIconName.bell),
    ('Perfil', AppIconName.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF00A0D12),
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final active = i == currentIndex;
            final color = active ? AppColors.green : AppColors.mutedDark;
            final (label, icon) = _items[i];
            return InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 30,
                          decoration: BoxDecoration(
                            color: active ? AppColors.greenSoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            border: active ? Border.all(color: AppColors.green.withOpacity(0.14)) : null,
                          ),
                          alignment: Alignment.center,
                          child: AppIcon(icon, color: color, size: 18),
                        ),
                        if (i == 3 && showAlertDot)
                          Positioned(
                            top: -2,
                            right: 2,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

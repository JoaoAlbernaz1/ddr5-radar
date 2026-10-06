import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Linha horizontal rolável de chips selecionáveis — usada na busca,
/// no filtro e no seletor de categoria.
class ChipRow extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;

  const ChipRow({super.key, required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final active = item == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(item),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: active ? AppColors.greenSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: active ? AppColors.green.withOpacity(0.28) : AppColors.line),
                ),
                alignment: Alignment.center,
                child: Text(
                  item,
                  style: AppText.mono.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.green : AppColors.muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// O mesmo conjunto de ícones de traço fino (stroke-width 1.7, linhas
/// arredondadas) usado no protótipo gerado no Figma Make — em vez do
/// Material Icons genérico. Cada entrada é o `d`/conteúdo exato dos
/// `<path>` originais, só re-embalado como SVG pro Flutter renderizar.
enum AppIconName {
  activity,
  arrow, // chevron pra esquerda — usado como "voltar" e, rotacionado 180°, como "avançar"
  bell,
  bookmark,
  box,
  cpu,
  edit,
  gpu,
  memory,
  plus,
  radar,
  search,
  settings,
  ssd,
  target,
  trash,
  user,
  zap,
}

const Map<AppIconName, String> _paths = {
  AppIconName.activity: '<path d="M3 12h4l2.2-6 4.2 12 2.1-6H21"/>',
  AppIconName.arrow: '<path d="m15 18-6-6 6-6"/>',
  AppIconName.bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M13.8 21a2 2 0 0 1-3.6 0"/>',
  AppIconName.bookmark: '<path d="M6 3h12v18l-6-4-6 4V3Z"/>',
  AppIconName.box: '<path d="m21 8-9-5-9 5 9 5 9-5Z"/><path d="m3 8 9 5v9l9-5V8M12 13v9"/>',
  AppIconName.cpu: '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9" y="9" width="6" height="6" rx="1"/><path d="M9 2v4m6-4v4M9 18v4m6-4v4M2 9h4m-4 6h4m12-6h4m-4 6h4"/>',
  AppIconName.edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4Z"/>',
  AppIconName.gpu: '<rect x="2" y="6" width="18" height="12" rx="2"/><circle cx="9" cy="12" r="3"/><path d="M20 10h2v5h-2M5 18v2m10-2v2"/>',
  AppIconName.memory: '<rect x="3" y="7" width="18" height="10" rx="2"/><path d="M7 10h3v4H7zm7 0h3v4h-3zM7 17v3m3-3v3m4-3v3m3-3v3"/>',
  AppIconName.plus: '<path d="M12 5v14M5 12h14"/>',
  AppIconName.radar: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><path d="M12 12 18.5 5.5"/><circle cx="12" cy="12" r="1" fill="currentColor"/>',
  AppIconName.search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
  AppIconName.settings:
      '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z"/>',
  AppIconName.ssd: '<rect x="5" y="2" width="14" height="20" rx="2"/><circle cx="12" cy="8" r="3"/><path d="M9 16h6m-3-2v4"/>',
  AppIconName.target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',
  AppIconName.trash: '<path d="M3 6h18M8 6V3h8v3m3 0-1 15H6L5 6m5 4v7m4-7v7"/>',
  AppIconName.user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  AppIconName.zap: '<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/>',
};

class AppIcon extends StatelessWidget {
  final AppIconName name;
  final double size;
  final Color color;

  /// Gira 180° — usado pro mesmo `arrow` virar um chevron "pra frente"
  /// em linhas de lista, igual ao CSS original.
  final bool rotate180;

  const AppIcon(this.name, {super.key, this.size = 20, required this.color, this.rotate180 = false});

  @override
  Widget build(BuildContext context) {
    final hex = '#${color.value.toRadixString(16).substring(2)}';
    final body = (_paths[name] ?? '').replaceAll('currentColor', hex);
    final svg = '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" '
        'stroke="$hex" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'
        '$body</svg>';
    final child = SvgPicture.string(svg, width: size, height: size);
    if (!rotate180) return child;
    return Transform.rotate(angle: math.pi, child: child);
  }
}

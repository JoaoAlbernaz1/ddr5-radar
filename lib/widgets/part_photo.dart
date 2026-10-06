import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

const Map<String, String> _categoryImage = {
  'GPU': 'https://images.unsplash.com/photo-1555618254-84e2cf498b01?auto=format&fit=crop&w=640&q=85',
  'CPU': 'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?auto=format&fit=crop&w=640&q=85',
  'RAM': 'https://images.unsplash.com/photo-1541029071515-84cc54f84dc5?auto=format&fit=crop&w=640&q=85',
  'SSD': 'https://images.unsplash.com/photo-1601737487795-dab272f52420?auto=format&fit=crop&w=640&q=85',
};

const Map<String, AppIconName> _categoryIcon = {
  'GPU': AppIconName.gpu,
  'CPU': AppIconName.cpu,
  'RAM': AppIconName.memory,
  'SSD': AppIconName.ssd,
};

/// Miniatura de peça: foto real da categoria (via Unsplash, como no
/// protótipo web) com um fallback de ícone caso a imagem falhe.
class PartPhoto extends StatelessWidget {
  final String category;
  final double size;
  final BorderRadius? borderRadius;

  const PartPhoto({super.key, required this.category, this.size = 64, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _categoryImage[category];
    final icon = _categoryIcon[category] ?? AppIconName.box;
    final radius = borderRadius ?? BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceHigh,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: AppIcon(icon, color: AppColors.green, size: size * 0.4)),
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.08),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                loadingBuilder: (context, child, progress) => progress == null ? child : const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                  stops: const [0.5, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

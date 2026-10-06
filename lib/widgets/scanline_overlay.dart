import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Linha verde fina varrendo de cima a baixo da tela, em loop — o
/// detalhe de assinatura visual do PartWatch (`.scanline` no protótipo
/// web). Puramente decorativo: `IgnorePointer` garante que não atrapalha
/// o toque no conteúdo por baixo.
class ScanlineOverlay extends StatefulWidget {
  const ScanlineOverlay({super.key});

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: _controller.value * constraints.maxHeight,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: AppColors.green.withOpacity(0.15),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.5), blurRadius: 6)],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

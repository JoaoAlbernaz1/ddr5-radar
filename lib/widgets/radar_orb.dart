import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// O "orbe de radar" animado — círculos concêntricos com uma linha
/// varrendo em volta, igual ao `.radar-orb` do protótipo web. Usado no
/// topo da Wishlist e no Onboarding.
class RadarOrb extends StatefulWidget {
  final double size;
  final Color accent;

  const RadarOrb({super.key, this.size = 100, this.accent = AppColors.green});

  @override
  State<RadarOrb> createState() => _RadarOrbState();
}

class _RadarOrbState extends State<RadarOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.accent.withOpacity(0.08)),
              gradient: RadialGradient(
                colors: [widget.accent.withOpacity(0.08), Colors.transparent],
                stops: const [0, 0.68],
              ),
            ),
          ),
          Container(
            width: widget.size * 0.73,
            height: widget.size * 0.73,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.accent.withOpacity(0.14)),
            ),
          ),
          Container(
            width: widget.size * 0.43,
            height: widget.size * 0.43,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.accent.withOpacity(0.14)),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: child,
              );
            },
            child: Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(widget.size * 0.19, 0),
                child: Container(
                  width: widget.size * 0.38,
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [widget.accent, widget.accent.withOpacity(0)]),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: widget.size * 0.17,
            height: widget.size * 0.17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accent,
              boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.7), blurRadius: 10)],
            ),
          ),
        ],
      ),
    );
  }
}

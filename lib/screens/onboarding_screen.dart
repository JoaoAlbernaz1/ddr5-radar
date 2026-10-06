import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import '../widgets/logo.dart';
import '../widgets/radar_orb.dart';

class _Slide {
  final AppIconName icon;
  final String tag;
  final String title;
  final String text;
  const _Slide({required this.icon, required this.tag, required this.title, required this.text});
}

const _slides = [
  _Slide(
    icon: AppIconName.radar,
    tag: 'MONITORAMENTO 24/7',
    title: 'Seu radar de hardware.',
    text: 'Acompanhe os preços das peças que você quer e encontre o momento certo para comprar.',
  ),
  _Slide(
    icon: AppIconName.activity,
    tag: 'PREÇO EM TEMPO REAL',
    title: 'Cada queda. Cada loja.',
    text: 'Comparamos ofertas nas principais lojas e mostramos o histórico completo de cada componente.',
  ),
  _Slide(
    icon: AppIconName.bell,
    tag: 'ALERTA DE ALVO',
    title: 'O sinal chega até você.',
    text: 'Defina seu preço ideal e receba um alerta assim que uma oferta atingir o seu alvo.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_step];
    final isLast = _step == _slides.length - 1;
    final accent = _step == 2 ? AppColors.purple : AppColors.green;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const PartWatchLogo(),
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text('Pular', style: AppText.body.copyWith(fontSize: 13)),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        RadarOrb(size: 200, accent: accent),
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: accent == AppColors.purple ? const Color(0xFF151124) : const Color(0xFF0D1816),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: accent.withOpacity(0.3)),
                            boxShadow: [BoxShadow(color: accent.withOpacity(0.18), blurRadius: 36)],
                          ),
                          alignment: Alignment.center,
                          child: AppIcon(slide.icon, size: 38, color: accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(slide.tag, style: AppText.eyebrow.copyWith(color: accent)),
                    const SizedBox(height: 12),
                    Text(slide.title, textAlign: TextAlign.center, style: AppText.h2),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(slide.text, textAlign: TextAlign.center, style: AppText.body),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _step;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? AppColors.green : AppColors.line,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              AppButton(
                label: isLast ? 'Começar' : 'Continuar',
                icon: isLast ? AppIconName.zap : null,
                onPressed: () {
                  if (isLast) {
                    widget.onDone();
                  } else {
                    setState(() => _step++);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

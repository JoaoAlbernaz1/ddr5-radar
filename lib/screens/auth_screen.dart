import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import '../widgets/logo.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signup = false;
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: PartWatchLogo(iconSize: 28)),
                const SizedBox(height: 48),
                Column(
                  children: [
                    Text(_signup ? 'NOVO OPERADOR' : 'ACESSO AO RADAR', style: AppText.eyebrow, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(_signup ? 'Criar conta' : 'Bem-vindo de volta', style: AppText.h2, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      _signup
                          ? 'Configure seu radar de preços em poucos segundos.'
                          : 'Entre para continuar monitorando suas peças.',
                      style: AppText.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (_signup) ...[
                  _AuthField(label: 'NOME', icon: AppIconName.user, hint: 'Seu nome'),
                  const SizedBox(height: 16),
                ],
                _AuthField(label: 'E-MAIL', iconText: '@', hint: 'voce@email.com'),
                const SizedBox(height: 16),
                _AuthField(label: 'SENHA', icon: AppIconName.target, hint: '••••••••', obscure: true),
                const SizedBox(height: 24),
                AppButton(
                  label: _signup ? 'Criar conta' : 'Entrar',
                  onPressed: widget.onAuthenticated,
                ),
                const SizedBox(height: 16),
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: AppText.body.copyWith(fontSize: 11),
                      children: [
                        TextSpan(text: _signup ? 'Já tem conta? ' : 'Não tem conta? '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => setState(() => _signup = !_signup),
                            child: Text(
                              _signup ? 'Entrar' : 'Criar agora',
                              style: AppText.body.copyWith(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.line)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('ou', style: AppText.monoSmall),
                    ),
                    const Expanded(child: Divider(color: AppColors.line)),
                  ],
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: 'Continuar com Google',
                  variant: AppButtonVariant.ghost,
                  onPressed: widget.onAuthenticated,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('Conexão segura com a central', style: AppText.monoSmall),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final String label;
  final AppIconName? icon;
  final String? iconText;
  final String hint;
  final bool obscure;

  const _AuthField({required this.label, this.icon, this.iconText, required this.hint, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.monoSmall.copyWith(color: AppColors.muted)),
        const SizedBox(height: 7),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              if (icon != null) AppIcon(icon!, size: 17, color: AppColors.mutedDark),
              if (iconText != null) Text(iconText!, style: AppText.mono.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mutedDark)),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  obscureText: obscure,
                  style: AppText.label,
                  decoration: InputDecoration.collapsed(
                    hintText: hint,
                    hintStyle: AppText.label.copyWith(color: AppColors.mutedDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

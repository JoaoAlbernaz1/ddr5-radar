import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/logo.dart';

/// Email/password Auth. Google login is intentionally hidden until configured.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      if (_signup) {
        final response = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'full_name': _name.text.trim()},
        );
        if (!mounted) return;
        if (response.session == null) {
          setState(() {
            _message = 'Conta solicitada! Confira seu e-mail para confirmar '
                'o cadastro e depois entre com sua senha.';
            _signup = false;
          });
        } else {
          widget.onAuthenticated();
        }
      } else {
        final response = await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (!mounted) return;
        if (response.session == null) {
          setState(() => _message = 'Confirme seu e-mail antes de entrar.');
        } else {
          widget.onAuthenticated();
        }
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _message = 'Não foi possível conectar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    bool password = false,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.monoSmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: password,
          keyboardType: keyboard,
          enableSuggestions: !password,
          autocorrect: !password,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Obrigatório';
            if (password && value.length < 6) {
              return 'Use pelo menos 6 caracteres.';
            }
            if (keyboard == TextInputType.emailAddress &&
                !value.trim().contains('@')) {
              return 'Informe um e-mail válido.';
            }
            return null;
          },
          style: AppText.label,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: PartWatchLogo(iconSize: 28)),
                  const SizedBox(height: 42),
                  Text(
                    _signup ? 'CRIAR CONTA' : 'ACESSO AO RADAR',
                    style: AppText.eyebrow,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _signup ? 'Crie seu monitor' : 'Bem-vindo de volta',
                    style: AppText.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  if (_signup) ...[
                    _field(label: 'NOME', controller: _name),
                    const SizedBox(height: 16),
                  ],
                  _field(
                    label: 'E-MAIL',
                    controller: _email,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    label: 'SENHA',
                    controller: _password,
                    password: true,
                  ),
                  const SizedBox(height: 20),
                  if (_message != null) ...[
                    Text(_message!, style: AppText.body),
                    const SizedBox(height: 16),
                  ],
                  AppButton(
                    label: _busy
                        ? 'Conectando...'
                        : (_signup ? 'Criar conta' : 'Entrar'),
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _signup = !_signup;
                              _message = null;
                            }),
                    child: Text(
                      _signup ? 'Já tem conta? Entrar' : 'Não tem conta? Criar',
                      style: AppText.body.copyWith(color: AppColors.green),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Login por Google ficará disponível após a configuração '
                    'do provedor no Supabase.',
                    style: AppText.monoSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

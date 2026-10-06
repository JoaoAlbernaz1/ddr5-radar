import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/parts_repository.dart';
import 'navigation/root_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PartWatchApp());
}

class PartWatchApp extends StatelessWidget {
  const PartWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PartsRepository()..load(),
      child: MaterialApp(
        title: 'PartWatch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const _AppFlow(),
      ),
    );
  }
}

enum _Stage { onboarding, auth, app }

/// Controla o fluxo inicial: Onboarding -> Login/Cadastro -> App.
/// Numa versão real, isso seria dirigido por um estado de sessão
/// persistido (já logado? já viu o onboarding?) em vez de sempre
/// reiniciar do zero.
class _AppFlow extends StatefulWidget {
  const _AppFlow();

  @override
  State<_AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<_AppFlow> {
  _Stage _stage = _Stage.onboarding;

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.onboarding:
        return OnboardingScreen(onDone: () => setState(() => _stage = _Stage.auth));
      case _Stage.auth:
        return AuthScreen(onAuthenticated: () => setState(() => _stage = _Stage.app));
      case _Stage.app:
        return RootShell(onLogout: () => setState(() => _stage = _Stage.auth));
    }
  }
}

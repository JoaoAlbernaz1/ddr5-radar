import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/parts_repository.dart';
import 'navigation/root_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

/// The publishable key is designed for public mobile clients.
/// Authorization is enforced by Supabase Auth + database RLS.
/// NEVER put a service-role/secret API key into this application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://xlmurmfdkkvnalwsbyfa.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_mkYBZZwf1jVPWUavu_yqqA_vTRPfIgX',
    ),
  );
  runApp(const PartWatchApp());
}

class PartWatchApp extends StatelessWidget {
  const PartWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PartsRepository(),
      child: MaterialApp(
        title: 'PartWatch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const _AppFlow(),
      ),
    );
  }
}

enum _Stage { loading, onboarding, auth, app }

class _AppFlow extends StatefulWidget {
  const _AppFlow();

  @override
  State<_AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<_AppFlow> {
  _Stage _stage = _Stage.loading;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.signedOut) {
        context.read<PartsRepository>().clear();
        setState(() => _stage = _Stage.auth);
      } else if (state.event == AuthChangeEvent.signedIn &&
          state.session != null) {
        _enterApp();
      }
    });
    _resolveInitialState();
  }

  Future<void> _resolveInitialState() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (Supabase.instance.client.auth.currentSession != null) {
      _enterApp();
    } else {
      final done = preferences.getBool('partwatch_onboarded') ?? false;
      setState(() => _stage = done ? _Stage.auth : _Stage.onboarding);
    }
  }

  void _enterApp() {
    if (!mounted) return;
    setState(() => _stage = _Stage.app);
    // The repository catches load failures and surfaces them in the UI.
    context.read<PartsRepository>().load();
  }

  Future<void> _finishOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('partwatch_onboarded', true);
    if (mounted) setState(() => _stage = _Stage.auth);
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.read<PartsRepository>().clear();
      setState(() => _stage = _Stage.auth);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível sair: ' + error.message)),
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _Stage.onboarding:
        return OnboardingScreen(onDone: _finishOnboarding);
      case _Stage.auth:
        return AuthScreen(onAuthenticated: _enterApp);
      case _Stage.app:
        return RootShell(onLogout: _logout);
    }
  }
}

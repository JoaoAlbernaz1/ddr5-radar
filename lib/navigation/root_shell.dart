import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/scanline_overlay.dart';
import '../screens/wishlist_screen.dart';
import '../screens/add_part_screen.dart';
import '../screens/search_screen.dart';
import '../screens/builds_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';

class RootShell extends StatefulWidget {
  final VoidCallback onLogout;
  const RootShell({super.key, required this.onLogout});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      WishlistScreen(onAddPressed: _openAddSheet),
      const SearchScreen(),
      const BuildsScreen(),
      const NotificationsScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: screens),
          const ScanlineOverlay(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _goTo, showAlertDot: true),
    );
  }

  void _openAddSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddPartScreen(onSaved: () => Navigator.of(context).pop())),
    );
  }
}

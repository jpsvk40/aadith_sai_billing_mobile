import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';

class AppBottomNavBar extends ConsumerWidget {
  final Widget child;
  const AppBottomNavBar({super.key, required this.child});

  static const _allTabs = [
    _NavTab(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home, route: '/dashboard'),
    _NavTab(label: 'Orders', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, route: '/orders'),
    _NavTab(label: 'Collections', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, route: '/collections'),
    _NavTab(label: 'Alerts', icon: Icons.notifications_outlined, activeIcon: Icons.notifications, route: '/alerts'),
    _NavTab(label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person, route: '/profile'),
  ];

  List<_NavTab> _getTabsForUser(dynamic user) {
    final tabs = <_NavTab>[_allTabs[0]];
    if (user?.hasModule('orders') == true) tabs.add(_allTabs[1]);
    if (user?.hasModule('collections') == true) tabs.add(_allTabs[2]);
    if (user?.hasModule('alerts') == true) tabs.add(_allTabs[3]);
    tabs.add(_allTabs[4]);
    return tabs;
  }

  int _currentIndex(String location, List<_NavTab> tabs) {
    for (var i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final tabs = _getTabsForUser(user);
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _currentIndex(location, tabs);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => context.go(tabs[i].route),
        items: tabs
            .map(
              (t) => BottomNavigationBarItem(
                icon: Icon(t.icon),
                activeIcon: Icon(t.activeIcon, color: AppColors.primary),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';

class AppBottomNavBar extends ConsumerWidget {
  final Widget child;
  const AppBottomNavBar({super.key, required this.child});

  static const _home = _NavTab(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home, route: '/dashboard');
  static const _orders = _NavTab(label: 'Orders', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, route: '/orders');
  static const _payments = _NavTab(label: 'Payments', icon: Icons.payments_outlined, activeIcon: Icons.payments, route: '/payments');
  static const _collections = _NavTab(label: 'Collections', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, route: '/collections');
  static const _commission = _NavTab(label: 'Commission', icon: Icons.percent_outlined, activeIcon: Icons.percent, route: '/commissions');
  static const _alerts = _NavTab(label: 'Alerts', icon: Icons.notifications_outlined, activeIcon: Icons.notifications, route: '/alerts');
  static const _profile = _NavTab(label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person, route: '/profile');

  List<_NavTab> _getTabsForUser(dynamic user) {
    final tabs = <_NavTab>[_home];
    final isRep = user?.isSalesRep == true || user?.isCollectionRep == true;
    if (isRep) {
      // Reps: module-driven (handles a rep who does both sales + collection).
      if (user?.hasModule('orders') == true) tabs.add(_orders);
      if (user?.hasModule('collections') == true) tabs.add(_collections);
      if (user?.hasModule('reports') == true) tabs.add(_commission);
    } else {
      // Owner / admin / manager.
      if (user?.hasModule('orders') == true) tabs.add(_orders);
      if (user?.hasModule('payments') == true) tabs.add(_payments);
      if (user?.hasModule('alerts') == true) tabs.add(_alerts);
    }
    tabs.add(_profile);
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(tabs[i].route),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          elevation: 0,
          iconSize: 26,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 11.5,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: tabs
              .map(
                (t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ),
              )
              .toList(),
        ),
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

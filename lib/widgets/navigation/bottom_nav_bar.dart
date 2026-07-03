import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'floating_assistant_button.dart';

class AppBottomNavBar extends ConsumerWidget {
  final Widget child;
  const AppBottomNavBar({super.key, required this.child});

  static const _home = _NavTab(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home, route: '/dashboard');
  static const _orders = _NavTab(label: 'Orders', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, route: '/orders');
  static const _payments = _NavTab(label: 'Payments', icon: Icons.payments_outlined, activeIcon: Icons.payments, route: '/payments');
  static const _collections = _NavTab(label: 'Collections', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, route: '/collections');
  static const _commission = _NavTab(label: 'Commission', icon: Icons.percent_outlined, activeIcon: Icons.percent, route: '/commissions');
  static const _alerts = _NavTab(label: 'Alerts', icon: Icons.notifications_outlined, activeIcon: Icons.notifications, route: '/alerts');
  static const _approvals = _NavTab(label: 'Approvals', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check, route: '/approvals');
  static const _profile = _NavTab(label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person, route: '/profile');
  // ERP (construction) module tabs — replace Payments/Approvals for ERP admins.
  static const _projects = _NavTab(label: 'Projects', icon: Icons.apartment_outlined, activeIcon: Icons.apartment, route: '/projects');
  static const _tenders = _NavTab(label: 'Tenders', icon: Icons.gavel_outlined, activeIcon: Icons.gavel, route: '/tenders');
  static const _machinery = _NavTab(label: 'Machinery', icon: Icons.agriculture_outlined, activeIcon: Icons.agriculture, route: '/machinery');
  static const _letters = _NavTab(label: 'Letters', icon: Icons.mail_outline, activeIcon: Icons.mail, route: '/correspondence');
  // Machinery field persona (operator) tabs.
  static const _machHome = _NavTab(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home, route: '/machinery/home');
  static const _myMachines = _NavTab(label: 'Machines', icon: Icons.agriculture_outlined, activeIcon: Icons.agriculture, route: '/machinery');
  // Shared back-office ("spine") finance persona + employee ESS tabs.
  static const _finance = _NavTab(label: 'Finance', icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance, route: '/finance');
  static const _ess = _NavTab(label: 'My ESS', icon: Icons.badge_outlined, activeIcon: Icons.badge, route: '/ess');
  // Service & Warranty persona tabs.
  static const _techHome = _NavTab(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home, route: '/service/home');
  static const _myTickets = _NavTab(label: 'My Tickets', icon: Icons.build_circle_outlined, activeIcon: Icons.build_circle, route: '/service/tickets');
  static const _today = _NavTab(label: 'Today', icon: Icons.event_outlined, activeIcon: Icons.event, route: '/service/today');
  static const _service = _NavTab(label: 'Service', icon: Icons.handyman_outlined, activeIcon: Icons.handyman, route: '/service/dashboard');

  List<_NavTab> _getTabsForUser(dynamic user) {
    // Technician persona: My Day home + their queue + AMC visits, no financial tabs.
    if (user?.isTechnician == true && user?.hasModule('warranty_service') == true) {
      final t = <_NavTab>[_techHome, _myTickets, _today];
      if (user?.hasModule('alerts') == true) t.add(_alerts);
      t.add(_profile);
      return t;
    }

    // Machine-operator persona: My Machines home + their fleet, no financial tabs.
    if (user?.isOperator == true && user?.hasModule('machinery') == true) {
      final t = <_NavTab>[_machHome, _myMachines];
      if (user?.hasModule('alerts') == true) t.add(_alerts);
      t.add(_profile);
      return t;
    }

    // Employee persona: ESS self-service only (auth-only — the employee role has no modules).
    if (user?.isEmployee == true) {
      return <_NavTab>[_ess, _profile];
    }

    final tabs = <_NavTab>[_home];
    final isRep = user?.isSalesRep == true || user?.isCollectionRep == true;
    if (isRep) {
      // Reps: module-driven (handles a rep who does both sales + collection).
      if (user?.hasModule('orders') == true) tabs.add(_orders);
      if (user?.hasModule('collections') == true) tabs.add(_collections);
      if (user?.hasModule('reports') == true) tabs.add(_commission);
    } else {
      // ERP (construction) admins get their module tabs — Projects/Tenders/Machinery/Letters —
      // instead of Payments/Approvals (those stay reachable from Home quick-access + Action Center).
      final isErp = user?.hasModule('projects') == true ||
          user?.hasModule('machinery') == true ||
          user?.hasModule('tender') == true;
      if (isErp) {
        if (user?.hasModule('projects') == true) tabs.add(_projects);
        if (user?.hasModule('tender') == true) tabs.add(_tenders);
        if (user?.hasModule('machinery') == true) tabs.add(_machinery);
        if (user?.hasModule('correspondence') == true) tabs.add(_letters);
      } else {
        // Owner / admin / manager (billing). Approvals is the owner's action surface and replaces
        // the generic Alerts tab (alerts stay reachable via the hero bell + Home exceptions).
        if (user?.hasModule('orders') == true) tabs.add(_orders);
        // Finance roles get the shared-spine hub tab; otherwise keep the standalone Payments tab.
        if (user?.hasSpine == true) {
          tabs.add(_finance);
        } else if (user?.hasModule('payments') == true) {
          tabs.add(_payments);
        }
        if (user?.hasModule('warranty_service') == true) tabs.add(_service);
        tabs.add(_approvals);
      }
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
    // Scale down when there are many tabs (ERP admins can have 6) so labels don't clip.
    final many = tabs.length >= 6;

    return Scaffold(
      body: Stack(
        children: [
          child,
          // Always-on, draggable AI assistant launcher over every tab.
          const FloatingAssistantButton(),
        ],
      ),
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
          iconSize: many ? 22 : 26,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedFontSize: many ? 10 : 12,
          unselectedFontSize: many ? 9.5 : 11.5,
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

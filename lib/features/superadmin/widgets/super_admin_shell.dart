import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

/// The platform (super admin) shell — its own four-tab bottom nav, completely
/// separate from the tenant `AppBottomNavBar`. No tenant modules, no floating
/// assistant; just the Control Tower, Companies, Queue and Platform settings.
class SuperAdminShell extends StatelessWidget {
  final Widget child;
  const SuperAdminShell({super.key, required this.child});

  static const _tabs = <_SaTab>[
    _SaTab('Overview', Icons.satellite_alt_outlined, Icons.satellite_alt, '/superadmin'),
    _SaTab('Companies', Icons.business_outlined, Icons.business, '/superadmin/companies'),
    _SaTab('Queue', Icons.fact_check_outlined, Icons.fact_check, '/superadmin/queue'),
    _SaTab('Platform', Icons.tune_outlined, Icons.tune, '/superadmin/settings'),
  ];

  // Longest-prefix match so /superadmin/companies/:id keeps the Companies tab lit
  // and bare /superadmin (a prefix of everything) only wins on an exact match.
  int _indexFor(String loc) {
    if (loc.startsWith('/superadmin/companies')) return 1;
    if (loc.startsWith('/superadmin/queue')) return 2;
    if (loc.startsWith('/superadmin/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final current = _indexFor(loc);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: current,
          onTap: (i) => context.go(_tabs[i].route),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          elevation: 0,
          iconSize: 25,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedFontSize: 11.5,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: _tabs
              .map((t) => BottomNavigationBarItem(icon: Icon(t.icon), activeIcon: Icon(t.activeIcon), label: t.label))
              .toList(),
        ),
      ),
    );
  }
}

class _SaTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  const _SaTab(this.label, this.icon, this.activeIcon, this.route);
}

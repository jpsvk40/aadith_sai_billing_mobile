import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

/// Shared back-office ("spine") hub — the finance persona's home surface. Renders ONE
/// tile per spine module the user actually has (`effectiveModules ∩ role`). Identical in
/// Trading, Service and Construction companies — the module set is what differs.
class FinanceHubScreen extends ConsumerWidget {
  const FinanceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    bool has(String m) => user?.hasModule(m) == true;

    // (icon, title, subtitle, color, module-gate, route)
    final tiles = <(IconData, String, String, Color, String, String)>[
      (Icons.people_alt_outlined, 'Customers', 'Parties & CRUD', const Color(0xFF1D4ED8), 'customers', '/customers'),
      (Icons.account_balance_wallet_outlined, 'Collections', 'Field collection book', const Color(0xFF0D9488), 'collections', '/collections'),
      (Icons.percent_outlined, 'Rep Commission', 'Leaderboard & settlements', const Color(0xFF7C3AED), 'reports', '/commissions'),
      (Icons.receipt_long_outlined, 'GST', 'Liability & compliance', const Color(0xFF0891B2), 'gst', '/finance/gst'),
      (Icons.account_balance_outlined, 'Payables', 'Vendor dues & credit notes', const Color(0xFFEF4444), 'vendor_purchases', '/finance/payables'),
      (Icons.inventory_2_outlined, 'Inventory', 'Stock valuation', const Color(0xFF7C3AED), 'inventory', '/finance/inventory'),
      (Icons.request_quote_outlined, 'Expenses', 'Office & petty cash', const Color(0xFFD97706), 'finance_accounts', '/finance/expenses'),
      (Icons.account_balance_wallet_outlined, 'Advances', 'Staff advance floats', const Color(0xFF7C3AED), 'finance_accounts', '/finance/advances'),
      (Icons.menu_book_outlined, 'General Ledger', 'Ledger · TB · P&L · Day book', const Color(0xFF6366F1), 'finance_gl', '/finance/gl'),
      (Icons.groups_outlined, 'Payroll', 'Runs & advances', const Color(0xFF059669), 'payroll', '/finance/payroll'),
    ].where((t) => has(t.$5)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Finance')),
      body: tiles.isEmpty
          ? const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No finance modules enabled for your role.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            ))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Hero
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Stack(children: [
                      Positioned(right: -22, top: -22, child: Container(width: 105, height: 105, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(13)),
                          child: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Back office', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(height: 3),
                            Text(user?.companyName ?? 'Finance, tax & payroll in one place', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.82))),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(9)),
                          child: Text('${tiles.length} module${tiles.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: tiles.map((t) => _tile(context, t.$1, t.$2, t.$3, t.$4, t.$6)).toList(),
                ),
              ],
            ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, Color color, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Icon(icon, color: Colors.white, size: 23),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

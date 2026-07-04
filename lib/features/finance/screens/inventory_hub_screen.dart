import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../reports/screens/report_view_screen.dart';
import '../finance_reports.dart';

/// Inventory hub — the read surface for stock depth: stock state, item master,
/// locations, transfers, movements and valuation. One tile per view.
class InventoryHubScreen extends ConsumerWidget {
  const InventoryHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // (icon, title, subtitle, color, onTap)
    final tiles = <(IconData, String, String, Color, VoidCallback)>[
      (Icons.inventory_2_outlined, 'Stock', 'On-hand & reorder alerts', const Color(0xFF7C3AED), () => context.push('/finance/inventory/stock')),
      (Icons.category_outlined, 'Items', 'Item master & rates', const Color(0xFF1D4ED8), () => context.push('/finance/inventory/items')),
      (Icons.warehouse_outlined, 'Locations', 'Godowns & sites', const Color(0xFF0891B2), () => context.push('/finance/inventory/locations')),
      (Icons.swap_horiz_outlined, 'Transfers', 'Between locations', const Color(0xFFD97706), () => context.push('/finance/inventory/transfers')),
      (Icons.receipt_long_outlined, 'Movements', 'Stock ledger', const Color(0xFF059669), () => context.push('/finance/inventory/movements')),
      (Icons.calculate_outlined, 'Valuation', 'Stock value (WAC/LPP)', const Color(0xFFEF4444),
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportViewScreen(config: FinanceReports.inventoryValuation)))),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Inventory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Stock & materials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Read-only — items & entries are managed on web', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: tiles.map((t) => _tile(t.$1, t.$2, t.$3, t.$4, t.$5)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

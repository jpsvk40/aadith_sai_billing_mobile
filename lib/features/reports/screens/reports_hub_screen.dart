import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../report_registry.dart';

/// Owner-grade reports hub. Each tile opens a generic [ReportViewScreen] backed by an
/// existing `/api/reports/*` endpoint. The configs live in [ReportRegistry] so they are
/// also deep-linkable by key (`/reports/view/<key>`, used by the AI assistant).
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  static const _reports = ReportRegistry.salesReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Business Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Tap a report to view details', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: _reports.map((r) {
              return InkWell(
                onTap: () => context.push('/reports/view', extra: r),
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
                          color: r.color,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: r.color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Icon(r.icon, color: Colors.white, size: 23),
                      ),
                      const SizedBox(height: 12),
                      Text(r.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          ..._insightsSection(context, ref),
        ],
      ),
    );
  }

  List<Widget> _insightsSection(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final tiles = <Widget>[
      if (user?.hasModule('business_trace') == true)
        _insightTile(context, 'Customer Trace', 'Buying history, payments & risk', Icons.person_search_outlined, const Color(0xFF6366F1), '/insights/customer-trace'),
      if (user?.hasModule('sales_intelligence') == true)
        _insightTile(context, 'Sales Advisor', 'Customer health & product velocity', Icons.insights_outlined, const Color(0xFF0F766E), '/insights/sales-advisor'),
      if (user?.hasModule('inventory_intelligence') == true)
        _insightTile(context, 'Inventory Advisor', 'Stock health & reorder advice', Icons.inventory_2_outlined, const Color(0xFF0D6EFD), '/insights/inventory-advisor'),
    ];
    if (tiles.isEmpty) return const [];
    return [
      const SizedBox(height: 22),
      const Text('AI & Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      ...tiles,
    ];
  }

  Widget _insightTile(BuildContext context, String title, String subtitle, IconData icon, Color color, String route) => InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 21)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ])),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ]),
        ),
      );
}

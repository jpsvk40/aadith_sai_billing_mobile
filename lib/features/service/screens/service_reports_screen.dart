import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../providers/service_providers.dart';

/// Admin reports: revenue/margin, technician productivity, parts usage.
class ServiceReportsScreen extends ConsumerWidget {
  const ServiceReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceReportsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Service Reports')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(serviceReportsProvider)),
        data: (d) {
          final rev = (d['revenue'] as Map<String, dynamic>?) ?? {};
          final techs = (d['technicians'] as List<dynamic>?) ?? [];
          final parts = (d['parts'] as List<dynamic>?) ?? [];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(serviceReportsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card('Revenue & Margin', [
                  _row('Labour revenue', CurrencyUtils.format(rev['labourRevenue'] ?? 0)),
                  _row('Parts revenue', CurrencyUtils.format(rev['partsRevenue'] ?? 0)),
                  _row('Total billed', CurrencyUtils.format(rev['totalBilled'] ?? 0)),
                  _row('Collected', CurrencyUtils.format(rev['totalCollected'] ?? 0)),
                  _row('Outstanding', CurrencyUtils.format(rev['outstanding'] ?? 0)),
                  _row('Gross margin', CurrencyUtils.format(rev['grossMargin'] ?? 0), bold: true),
                ]),
                const SizedBox(height: 14),
                _card('Technician Productivity', [
                  if (techs.isEmpty) const Text('No data.', style: TextStyle(color: AppColors.textSecondary)),
                  ...techs.map((t) {
                    final m = t as Map<String, dynamic>;
                    return _row('${m['technicianName'] ?? '—'} (${m['jobs'] ?? 0} jobs)', CurrencyUtils.format(m['revenue'] ?? 0));
                  }),
                ]),
                const SizedBox(height: 14),
                _card('Top Parts Used', [
                  if (parts.isEmpty) const Text('No data.', style: TextStyle(color: AppColors.textSecondary)),
                  ...parts.take(10).map((p) {
                    final m = p as Map<String, dynamic>;
                    final item = (m['item'] as Map<String, dynamic>?);
                    return _row('${item?['itemName'] ?? '—'} ×${m['totalQuantity'] ?? 0}', CurrencyUtils.format(m['totalValue'] ?? 0));
                  }),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? AppColors.primary : AppColors.textPrimary)),
        ]),
      );
}

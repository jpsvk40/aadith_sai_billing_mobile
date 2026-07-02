import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../providers/service_providers.dart';
import '../service_status.dart';

/// Owner/Admin Service overview: KPI tiles + recent tickets. Tap a ticket → detail.
class ServiceDashboardScreen extends ConsumerWidget {
  const ServiceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceDashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Service'),
        actions: [
          IconButton(tooltip: 'Warranty lookup', icon: const Icon(Icons.qr_code_scanner), onPressed: () => context.go('/service/warranty-lookup')),
          IconButton(tooltip: 'All tickets', icon: const Icon(Icons.list_alt), onPressed: () => context.go('/service/tickets')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/service/tickets/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(serviceDashboardProvider)),
        data: (d) {
          final k = (d['kpis'] as Map<String, dynamic>?) ?? {};
          final rev = (d['revenueThisMonth'] as Map<String, dynamic>?) ?? {};
          final recent = (d['recentTickets'] as List<dynamic>?) ?? [];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(serviceDashboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.7,
                  children: [
                    _kpi('Open', '${k['openTotal'] ?? 0}', Icons.build_circle_outlined, AppColors.primary),
                    _kpi('Unassigned', '${k['unassigned'] ?? 0}', Icons.person_off_outlined, AppColors.warning),
                    _kpi('Ready', '${k['readyForDelivery'] ?? 0}', Icons.inventory_2_outlined, AppColors.success),
                    _kpi('SLA breached', '${k['slaBreached'] ?? 0}', Icons.warning_amber_rounded, AppColors.danger),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Expanded(child: _stat('Billed (mo)', CurrencyUtils.format(rev['billed'] ?? 0))),
                    Expanded(child: _stat('Collected', CurrencyUtils.format(rev['collected'] ?? 0))),
                    Expanded(child: _stat('Receivable', CurrencyUtils.format(k['outstandingReceivables'] ?? 0))),
                  ]),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _quickLink(context, 'All Tickets', Icons.list_alt, '/service/tickets'),
                  _quickLink(context, 'Calendar', Icons.calendar_month, '/service/calendar'),
                  _quickLink(context, 'Today (AMC)', Icons.event, '/service/today'),
                  _quickLink(context, 'Warranty', Icons.devices_other, '/service/items'),
                  _quickLink(context, 'Contracts', Icons.assignment_outlined, '/service/contracts'),
                  _quickLink(context, 'Reports', Icons.bar_chart, '/service/reports'),
                ]),
                const SizedBox(height: 16),
                const Text('Recent tickets', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                ...recent.map((r) => _recentTile(context, r as Map<String, dynamic>)),
                if (recent.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No recent tickets.', style: TextStyle(color: AppColors.textSecondary))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      );

  Widget _quickLink(BuildContext context, String label, IconData icon, String route) => InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _stat(String label, String value) => Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
      ]);

  Widget _recentTile(BuildContext context, Map<String, dynamic> r) {
    final status = (r['status'] ?? 'OPEN').toString();
    final cust = (r['customer'] as Map<String, dynamic>?)?['customerName']?.toString() ?? '—';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
      title: Text('${r['ticketNumber'] ?? ''}  ·  $cust', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(ServiceStatus.serviceTypeLabel((r['serviceType'] ?? '').toString())),
      trailing: ServiceStatusChip(status: status),
      onTap: () => context.go('/service/tickets/${r['id']}'),
    );
  }
}

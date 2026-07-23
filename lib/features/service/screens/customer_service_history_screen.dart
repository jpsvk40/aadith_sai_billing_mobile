import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/customer_service_history_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../providers/service_providers.dart';
import '../service_status.dart';

/// F1 — a customer's service & maintenance history (jobs, rework rate, revenue, warranty units, AMC).
class CustomerServiceHistoryScreen extends ConsumerWidget {
  final int customerId;
  const CustomerServiceHistoryScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerServiceHistoryProvider(customerId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Service History')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(customerServiceHistoryProvider(customerId))),
        data: (h) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(customerServiceHistoryProvider(customerId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(h),
              const SizedBox(height: 12),
              _tiles(h.stats),
              const SizedBox(height: 12),
              _recent(context, h),
              if (h.warrantyItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                _units(h),
              ],
              if (h.contracts.isNotEmpty) ...[
                const SizedBox(height: 12),
                _contracts(h),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(CustomerServiceHistory h) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 2),
          Text([h.customerCode, h.phone].where((e) => (e ?? '').isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (h.stats.lastServiceDate != null) ...[
            const SizedBox(height: 6),
            Text('Last service ${AppDateUtils.formatDisplay(h.stats.lastServiceDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ]),
      );

  Widget _tiles(ServiceHistoryStats s) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.1,
        children: [
          _tile('Service jobs', '${s.totalTickets}', '${s.openTickets} open', AppColors.primary),
          _tile('Rework', '${s.reworkTickets}', s.deliveredTickets > 0 ? '${(s.repeatRepairRate * 100).round()}% rate' : 'No delivered', const Color(0xFF7C3AED)),
          _tile('Service revenue', CurrencyUtils.format(s.totalServiceRevenue), null, AppColors.success),
          _tile('Outstanding', CurrencyUtils.format(s.serviceOutstanding), null, s.serviceOutstanding > 0 ? AppColors.warning : AppColors.textSecondary),
          _tile('Warranty units', '${s.warrantyItems}', '${s.activeWarrantyItems} active', AppColors.info),
          _tile('AMC / contracts', '${s.amcContracts}', '${s.activeAmc} active', AppColors.textPrimary),
        ],
      );

  Widget _tile(String label, String value, String? sub, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          if (sub != null) Text(sub, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ]),
      );

  Widget _recent(BuildContext context, CustomerServiceHistory h) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recent service', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 4),
          if (h.recentTickets.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No service history yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
          else
            ...h.recentTickets.map((t) => InkWell(
                  onTap: () => context.push('/service/tickets/${t.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(t.ticketNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.primary)),
                            if (t.isRework) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                child: const Text('rework', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ]),
                          if ((t.reportedProblem ?? '').isNotEmpty)
                            Text(t.reportedProblem!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(ServiceStatus.label(t.status), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ServiceStatus.color(t.status))),
                        Text(t.isChargeable ? CurrencyUtils.format(t.totalCharge) : 'Warranty', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      ]),
                    ]),
                  ),
                )),
        ]),
      );

  Widget _units(CustomerServiceHistory h) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Registered units', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: h.warrantyItems.map((u) {
            final c = u.warrantyStatus == 'ACTIVE' ? AppColors.success : (u.warrantyStatus == 'EXPIRED' ? AppColors.warning : AppColors.danger);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${u.label.isEmpty ? (u.category ?? 'Unit') : u.label} · ${u.serialNumber ?? ''}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                  child: Text(u.warrantyStatus, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          }).toList()),
        ]),
      );

  Widget _contracts(CustomerServiceHistory h) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AMC / contracts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 6),
          ...h.contracts.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text('${c.contractNumber} · ${c.contractType}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  if (c.endDate != null) Text('till ${AppDateUtils.formatDisplay(c.endDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Text(c.status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.status == 'ACTIVE' ? AppColors.success : AppColors.textSecondary)),
                ]),
              )),
        ]),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/service_ticket_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../providers/service_providers.dart';

/// F2 — "Out at company" worklist: units currently at the manufacturer (RMA status SENT),
/// with an overdue flag when the expected-return date has passed. Tap → the ticket.
class RmaOutstandingScreen extends ConsumerWidget {
  const RmaOutstandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rmaOutstandingProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Out at Company')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(rmaOutstandingProvider)),
        data: (rmas) {
          if (rmas.isEmpty) {
            return const EmptyStateWidget(icon: Icons.local_shipping_outlined, message: 'Nothing out at the company. Units sent to a manufacturer for warranty replacement show here until received back.');
          }
          final overdue = rmas.where((r) => r.overdue).length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(rmaOutstandingProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Text('${rmas.length} out at company', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (overdue > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text('$overdue overdue', style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                ...rmas.map((r) => _card(context, r)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, ServiceTicketRma r) {
    final chipColor = r.overdue ? AppColors.danger : (r.daysOut != null && r.daysOut! >= 4 ? AppColors.warning : AppColors.info);
    final chipText = r.overdue ? 'Overdue' : (r.daysOut != null ? '${r.daysOut}d out' : 'Sent');
    return InkWell(
      onTap: r.ticketId != null ? () => context.push('/service/tickets/${r.ticketId}') : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: r.overdue ? AppColors.danger.withValues(alpha: 0.55) : AppColors.border, width: r.overdue ? 1.4 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.rmaNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text([r.ticketDevice, r.ticketNumber].where((e) => (e ?? '').isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(chipText, style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.factory_outlined, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(r.company, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            if (r.expectedReturnAt != null)
              Text('Exp ${AppDateUtils.formatDisplay(r.expectedReturnAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}

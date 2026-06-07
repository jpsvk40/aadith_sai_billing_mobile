import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/status_badge.dart';
import '../providers/collection_detail_provider.dart';

class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;
  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionAsync = ref.watch(collectionDetailProvider(collectionId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/collections'),
        ),
        title: const Text('Collection Detail'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/collections/$collectionId/payment'),
            icon: const Icon(Icons.payment, color: AppColors.white, size: 18),
            label: const Text(
              'Collect',
              style: TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
      body: collectionAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.refresh(collectionDetailProvider(collectionId)),
        ),
        data: (collection) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          collection.customerName ?? 'Customer',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        StatusBadge(status: collection.status),
                      ],
                    ),
                    const Divider(height: 24),
                    _Row(
                      label: 'Total to Collect',
                      value: CurrencyUtils.format(collection.totalOutstanding),
                      valueColor: AppColors.textPrimary,
                    ),
                    if ((collection.collectedAmount ?? 0) > 0)
                      _Row(
                        label: 'Collected',
                        value: CurrencyUtils.format(collection.collectedAmount),
                        valueColor: AppColors.success,
                      ),
                    _Row(
                      label: 'Balance',
                      value: CurrencyUtils.format(collection.balanceAmount),
                      valueColor: collection.balanceAmount > 0
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                    if (collection.assignedDate != null)
                      _Row(
                        label: 'Assigned',
                        value: AppDateUtils.formatDisplay(
                          collection.assignedDate,
                        ),
                      ),
                    if (collection.dueDate != null)
                      _Row(
                        label: 'Due Date',
                        value: AppDateUtils.formatDisplay(collection.dueDate),
                      ),
                    if (collection.representativeName != null)
                      _Row(
                        label: 'Assigned To',
                        value: collection.representativeName!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (collection.payments.any((p) => p.isPending))
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top, color: Color(0xFFB45309), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment of ${CurrencyUtils.format(collection.payments.where((p) => p.isPending).fold<double>(0, (a, p) => a + p.amount))} submitted — awaiting admin approval.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (collection.payments.isNotEmpty) ...[
              Text(
                'Payment History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...collection.payments.map((payment) {
                final isCorr = payment.entryType == 'correction';
                final statusColor = payment.isPending
                    ? const Color(0xFFF59E0B)
                    : payment.isRejected
                        ? AppColors.danger
                        : AppColors.success;
                final statusLabel = payment.isPending
                    ? 'PENDING APPROVAL'
                    : payment.isRejected
                        ? 'REJECTED'
                        : 'APPROVED';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(isCorr ? Icons.remove_circle_outline : Icons.payments_outlined,
                            color: isCorr ? AppColors.danger : statusColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(CurrencyUtils.format(payment.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('${isCorr ? 'Correction' : 'Payment'} · ${payment.paymentMode} · ${AppDateUtils.formatDisplay(payment.paymentDate)}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
                          child: Text(statusLabel, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: statusColor)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/collections/$collectionId/payment'),
                icon: const Icon(Icons.payment),
                label: const Text('Record Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

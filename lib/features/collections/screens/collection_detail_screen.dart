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
          TextButton.icon(
            onPressed: () => context.go(
              '/collections/$collectionId/payment?mode=correction',
            ),
            icon: const Icon(
              Icons.remove_circle_outline,
              color: AppColors.white,
              size: 18,
            ),
            label: const Text(
              'Correct',
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
            const SizedBox(height: 16),
            if (collection.payments.isNotEmpty) ...[
              Text(
                'Payment History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...collection.payments.map(
                (payment) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      payment.entryType == 'correction'
                          ? Icons.remove_circle_outline
                          : Icons.check_circle_outline,
                      color: payment.entryType == 'correction'
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                    title: Text(
                      CurrencyUtils.format(payment.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${payment.entryType == 'correction' ? 'Correction' : 'Payment'} | ${payment.paymentMode} | ${AppDateUtils.formatDisplay(payment.paymentDate)}',
                    ),
                    trailing:
                        (payment.notes != null ||
                            payment.correctionReason != null)
                        ? Tooltip(
                            message: payment.correctionReason ?? payment.notes!,
                            child: const Icon(Icons.info_outline, size: 16),
                          )
                        : null,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.go('/collections/$collectionId/payment'),
                    icon: const Icon(Icons.payment),
                    label: const Text('Record Payment'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (collection.collectedAmount ?? 0) > 0
                        ? () => context.go(
                            '/collections/$collectionId/payment?mode=correction',
                          )
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Add Correction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.divider,
                      disabledForegroundColor: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
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

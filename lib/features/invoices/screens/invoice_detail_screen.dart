import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/status_badge.dart';
import '../providers/invoice_detail_provider.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Detail'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/payments/record?invoiceId=$invoiceId'),
            icon: const Icon(Icons.payment, color: AppColors.white, size: 18),
            label: const Text('Pay', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.refresh(invoiceDetailProvider(invoiceId))),
        data: (invoice) => ListView(
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
                        Text(invoice.invoiceNumber, style: Theme.of(context).textTheme.headlineSmall),
                        StatusBadge(status: invoice.isOverdue ? 'Overdue' : invoice.status),
                      ],
                    ),
                    const Divider(height: 24),
                    _Row(label: 'Customer', value: invoice.customerName ?? '-'),
                    _Row(label: 'Date', value: AppDateUtils.formatDisplay(invoice.invoiceDate)),
                    if (invoice.dueDate != null) _Row(label: 'Due Date', value: AppDateUtils.formatDisplay(invoice.dueDate)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (invoice.items.isNotEmpty) ...[
              Text('Items', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...invoice.items.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(
                                'Qty: ${item.quantity} x ${CurrencyUtils.format(item.price)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(CurrencyUtils.format(item.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _TotalRow(label: 'Subtotal', value: CurrencyUtils.format(invoice.subtotal)),
                    if ((invoice.cgst ?? 0) > 0) _TotalRow(label: 'CGST', value: CurrencyUtils.format(invoice.cgst)),
                    if ((invoice.sgst ?? 0) > 0) _TotalRow(label: 'SGST', value: CurrencyUtils.format(invoice.sgst)),
                    if ((invoice.igst ?? 0) > 0) _TotalRow(label: 'IGST', value: CurrencyUtils.format(invoice.igst)),
                    const Divider(),
                    _TotalRow(label: 'Total', value: CurrencyUtils.format(invoice.totalAmount), bold: true),
                    if ((invoice.paidAmount ?? 0) > 0)
                      _TotalRow(label: 'Paid', value: CurrencyUtils.format(invoice.paidAmount), color: AppColors.success),
                    if ((invoice.outstandingAmount ?? 0) > 0)
                      _TotalRow(
                        label: 'Outstanding',
                        value: CurrencyUtils.format(invoice.outstandingAmount),
                        color: AppColors.danger,
                        bold: true,
                      ),
                  ],
                ),
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
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _TotalRow({required this.label, required this.value, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14, color: color ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

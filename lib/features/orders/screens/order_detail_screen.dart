import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/status_badge.dart';
import '../providers/order_detail_provider.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Detail')),
      body: orderAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.refresh(orderDetailProvider(orderId))),
        data: (order) => ListView(
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
                        Text(order.orderNumber, style: Theme.of(context).textTheme.headlineSmall),
                        StatusBadge(status: order.status),
                      ],
                    ),
                    const Divider(height: 24),
                    _Row(label: 'Customer', value: order.customerName ?? '-'),
                    _Row(label: 'Date', value: AppDateUtils.formatDisplay(order.createdAt)),
                    if (order.deliveryDate != null) _Row(label: 'Delivery', value: AppDateUtils.formatDisplay(order.deliveryDate)),
                    if (order.representativeName != null) _Row(label: 'Rep', value: order.representativeName!),
                    if (order.notes != null && order.notes!.isNotEmpty) _Row(label: 'Notes', value: order.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (order.items.isNotEmpty) ...[
              Text('Order Items', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...order.items.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                'Qty: ${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(CurrencyUtils.format(item.rate), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            if (item.total != null)
                              Text(
                                CurrencyUtils.format(item.total),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (order.totalAmount != null)
              Card(
                margin: EdgeInsets.zero,
                color: AppColors.primaryLight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        CurrencyUtils.format(order.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}

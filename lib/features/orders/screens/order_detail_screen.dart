import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/order_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/order_detail_provider.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isSaving = false;

  Future<void> _openFinalQuantityReview(Order order) async {
    final itemStates = order.items
        .map(
          (item) => _EditableOrderItemState(
            item: item,
            confirmedController: TextEditingController(
              text: item.confirmedQuantity != null
                  ? _formatEditableQuantity(item.confirmedQuantity!)
                  : '',
            ),
            remarkController: TextEditingController(
              text: item.customerRemark ?? '',
            ),
          ),
        )
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String? validationMessage;

            Future<void> submit() async {
              for (final itemState in itemStates) {
                final confirmedText = itemState.confirmedController.text.trim();
                final orderedQuantity = itemState.item.quantity;
                final confirmedQuantity = confirmedText.isEmpty
                    ? null
                    : double.tryParse(confirmedText);

                if (confirmedQuantity == null && confirmedText.isNotEmpty) {
                  setModalState(
                    () => validationMessage =
                        'Confirmed quantity must be a valid number.',
                  );
                  return;
                }
                if (confirmedQuantity != null && confirmedQuantity < 0) {
                  setModalState(
                    () => validationMessage =
                        'Confirmed quantity cannot be negative.',
                  );
                  return;
                }
                if (confirmedQuantity != null &&
                    confirmedQuantity > orderedQuantity) {
                  setModalState(
                    () => validationMessage =
                        'Confirmed quantity cannot exceed ordered quantity.',
                  );
                  return;
                }
                if (confirmedQuantity != null &&
                    confirmedQuantity < orderedQuantity &&
                    itemState.remarkController.text.trim().isEmpty) {
                  setModalState(
                    () => validationMessage =
                        'Add a remark for any item that is short-closed.',
                  );
                  return;
                }
                if (itemState.item.productId == null ||
                    itemState.item.productId!.isEmpty) {
                  setModalState(
                    () => validationMessage =
                        'This order item is missing product information and cannot be updated from mobile.',
                  );
                  return;
                }
              }

              final payload = {
                'items': itemStates
                    .map(
                      (itemState) => {
                        'productId': int.tryParse(itemState.item.productId!),
                        'quantity': itemState.item.quantity,
                        'confirmedQuantity':
                            itemState.confirmedController.text.trim().isEmpty
                            ? null
                            : double.parse(
                                itemState.confirmedController.text.trim(),
                              ),
                        'customerRemark': itemState.remarkController.text
                            .trim(),
                        'rate': itemState.item.rate,
                        'discountType': itemState.item.discountType,
                        'discountValue': itemState.item.discountValue ?? 0,
                        'taxPercent': itemState.item.taxPercent ?? 0,
                      },
                    )
                    .toList(),
              };

              setState(() => _isSaving = true);
              try {
                final client = ApiClient.getInstance(
                  onUnauthorized: () =>
                      ref.read(authProvider.notifier).logout(),
                );
                final repository = OrderRepository(client);
                await repository.updateOrder(widget.orderId, payload);
                if (!context.mounted || !sheetContext.mounted) return;
                ref.invalidate(orderDetailProvider(widget.orderId));
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Final billable quantities updated successfully.',
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                setModalState(() => validationMessage = e.toString());
              } finally {
                if (mounted) {
                  setState(() => _isSaving = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Review Final Quantity',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Leave confirmed quantity blank to invoice the original order quantity. Enter a lower quantity only when production or accounts confirms a short close.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: itemStates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final itemState = itemStates[index];
                              final item = itemState.item;
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName ??
                                          'Product ${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ordered: ${_formatQuantity(item.quantity)}${item.unit != null ? ' ${item.unit}' : ''}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    AppTextField(
                                      label: 'Confirmed / Invoice Quantity',
                                      controller: itemState.confirmedController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      hint:
                                          'Leave blank to use ordered quantity',
                                    ),
                                    const SizedBox(height: 12),
                                    AppTextField(
                                      label: 'Customer Remark',
                                      controller: itemState.remarkController,
                                      maxLines: 2,
                                      hint:
                                          'Required only when confirmed quantity is lower than ordered quantity',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        if (validationMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              validationMessage!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : submit,
                            icon: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      color: AppColors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _isSaving
                                  ? 'Saving...'
                                  : 'Save Final Quantity Review',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    for (final itemState in itemStates) {
      itemState.confirmedController.dispose();
      itemState.remarkController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Detail'),
        actions: [
          orderAsync.maybeWhen(
            data: (order) => order.canReviewFinalQuantity
                ? TextButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _openFinalQuantityReview(order),
                    icon: const Icon(
                      Icons.edit_note,
                      color: AppColors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Review Qty',
                      style: TextStyle(color: AppColors.white),
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.refresh(orderDetailProvider(widget.orderId)),
        ),
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
                        Expanded(
                          child: Text(
                            order.orderNumber,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        StatusBadge(status: order.status),
                      ],
                    ),
                    const Divider(height: 24),
                    _Row(label: 'Customer', value: order.customerName ?? '-'),
                    _Row(
                      label: 'Date',
                      value: AppDateUtils.formatDisplay(order.createdAt),
                    ),
                    if (order.deliveryDate != null)
                      _Row(
                        label: 'Delivery',
                        value: AppDateUtils.formatDisplay(order.deliveryDate),
                      ),
                    if (order.representativeName != null)
                      _Row(label: 'Rep', value: order.representativeName!),
                    if (order.notes != null && order.notes!.isNotEmpty)
                      _Row(label: 'Notes', value: order.notes!),
                    if (order.canReviewFinalQuantity)
                      _Row(
                        label: 'Final Qty Review',
                        value: order.status == 'New'
                            ? 'Order can still be edited before production or invoicing.'
                            : 'Accounts can confirm final billable quantity before invoice.',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (order.items.isNotEmpty) ...[
              Text(
                'Order Items',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) {
                final invoiceQuantity = item.confirmedQuantity ?? item.quantity;
                final isShortClosed =
                    item.confirmedQuantity != null &&
                    item.confirmedQuantity! < item.quantity;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName ?? 'Product',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ordered Qty: ${_formatQuantity(item.quantity)}${item.unit != null ? ' ${item.unit}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'Invoice Qty: ${_formatQuantity(invoiceQuantity)}${item.unit != null ? ' ${item.unit}' : ''}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isShortClosed
                                          ? AppColors.warning
                                          : AppColors.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (item.customerRemark != null &&
                                      item.customerRemark!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        item.customerRemark!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyUtils.format(item.rate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (item.total != null)
                                  Text(
                                    CurrencyUtils.format(item.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (isShortClosed) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Short-closed item: invoice will follow confirmed quantity.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF856404),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
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
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        CurrencyUtils.format(order.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (order.canReviewFinalQuantity) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _openFinalQuantityReview(order),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Review Final Quantity'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditableOrderItemState {
  final OrderItem item;
  final TextEditingController confirmedController;
  final TextEditingController remarkController;

  const _EditableOrderItemState({
    required this.item,
    required this.confirmedController,
    required this.remarkController,
  });
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
          SizedBox(
            width: 90,
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
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatEditableQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

String _formatQuantity(double value) => _formatEditableQuantity(value);

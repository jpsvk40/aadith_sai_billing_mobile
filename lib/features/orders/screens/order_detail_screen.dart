import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/order_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/order_detail_provider.dart';

/// View-only Order Details — rich layout matching the approved design.
class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  void _soon(BuildContext c, String what) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$what — coming in the next update')));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          if (orderAsync.asData?.value.isEditable == true)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit order',
              onPressed: () {
                final o = orderAsync.asData?.value;
                if (o != null) context.push('/orders/${o.id}/edit', extra: o);
              },
            ),
          IconButton(icon: const Icon(Icons.print_outlined), onPressed: () => _soon(context, 'Print')),
        ],
      ),
      body: orderAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.refresh(orderDetailProvider(orderId))),
        data: (order) => RefreshIndicator(
          onRefresh: () async => ref.refresh(orderDetailProvider(orderId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _infoCard(context, order),
              const SizedBox(height: 14),
              _statBoxes(order),
              const SizedBox(height: 18),
              _itemsSection(context, order),
              const SizedBox(height: 14),
              _totalsRow(order),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Order info card ----
  Widget _infoCard(BuildContext context, Order order) {
    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(order.orderNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
              _statusPill(order.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _infoCol(Icons.event_outlined, 'Order Date', AppDateUtils.formatDisplay(order.createdAt))),
              Expanded(child: _infoCol(Icons.local_shipping_outlined, 'Delivery Date', order.deliveryDate != null ? AppDateUtils.formatDisplay(order.deliveryDate) : '-')),
              Expanded(child: _infoCol(Icons.badge_outlined, 'Rep', order.representativeName ?? '-')),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Customer', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 3),
                    Text(order.customerName ?? '-', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:${order.customerPhone}')),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.call, color: AppColors.primary, size: 20),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCol(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }

  // ---- 3 stat boxes ----
  Widget _statBoxes(Order order) {
    final totalQty = order.items.fold<double>(0, (s, i) => s + i.quantity);
    return Row(
      children: [
        Expanded(child: _statBox('${order.items.length}', 'Items', const Color(0xFFFDEAE0), AppColors.textPrimary)),
        const SizedBox(width: 10),
        Expanded(child: _statBox(_num(totalQty), 'Total Qty', const Color(0xFFEFF1F4), AppColors.textPrimary)),
        const SizedBox(width: 10),
        Expanded(child: _statBox(CurrencyUtils.format(order.totalAmount ?? 0), 'Total Amount', AppColors.successLight, AppColors.success)),
      ],
    );
  }

  Widget _statBox(String value, String label, Color bg, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ---- Items table ----
  Widget _itemsSection(BuildContext context, Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Order Items (${order.items.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        _card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                ),
                child: Row(
                  children: const [
                    Expanded(flex: 4, child: Text('Product', style: _thStyle)),
                    Expanded(flex: 3, child: Text('Qty / Unit', style: _thStyle)),
                    Expanded(flex: 2, child: Text('Rate', style: _thStyle, textAlign: TextAlign.right)),
                    Expanded(flex: 3, child: Text('Amount', style: _thStyle, textAlign: TextAlign.right)),
                  ],
                ),
              ),
              ...List.generate(order.items.length, (i) {
                final item = order.items[i];
                final unit = item.unit ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider, width: i == 0 ? 0 : 0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName ?? 'Product', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            if (item.variantLabel != null && item.variantLabel!.isNotEmpty)
                              Text(item.variantLabel!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Expanded(flex: 3, child: Text('${_num(item.quantity)}${unit.isNotEmpty ? ' $unit' : ''}', style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary))),
                      Expanded(flex: 2, child: Text(CurrencyUtils.format(item.rate), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
                      Expanded(flex: 3, child: Text(CurrencyUtils.format(item.total ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Subtotal / Tax / Total ----
  Widget _totalsRow(Order order) {
    final subtotal = order.subtotal > 0 ? order.subtotal : order.items.fold<double>(0, (s, i) => s + (i.total ?? 0));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _totalCol('Subtotal', CurrencyUtils.format(subtotal), AppColors.textPrimary)),
          Expanded(child: _totalCol('Tax', CurrencyUtils.format(order.taxTotal), AppColors.textPrimary)),
          Expanded(child: _totalCol('Total Amount', CurrencyUtils.format(order.totalAmount ?? 0), AppColors.success)),
        ],
      ),
    );
  }

  Widget _totalCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ---- Bottom action bar ----
  // ---- helpers ----
  Widget _card({required Widget child, EdgeInsets padding = EdgeInsets.zero}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  Widget _statusPill(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'New':
        return AppColors.primary;
      case 'In Production':
        return const Color(0xFF6F42C1);
      case 'Production Completed':
        return AppColors.info;
      case 'Packed':
        return AppColors.warning;
      case 'Dispatched':
        return const Color(0xFF0891B2);
      case 'Delivered':
        return AppColors.success;
      case 'Cancelled':
      case 'Void':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  String _num(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

const _thStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary);

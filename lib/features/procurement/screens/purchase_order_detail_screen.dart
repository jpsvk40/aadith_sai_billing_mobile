import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/procurement_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/procurement_providers.dart';
import '../widgets/procurement_list_view.dart';

/// Purchase Order detail — read-only lines + totals + status. The approval
/// gate, GRN receipt and bill/payment flow remain on the web.
class PurchaseOrderDetailScreen extends ConsumerWidget {
  const PurchaseOrderDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseOrderDetailProvider(id));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Purchase Order')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(purchaseOrderDetailProvider(id))),
        data: (po) => _body(context, ref, po),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, PurchaseOrder po) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(purchaseOrderDetailProvider(id)),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(po.poNumber.isEmpty ? 'Purchase Order' : po.poNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                    ProcStatusPill(po.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${AppDateUtils.formatDisplay(po.poDate)}  ·  ${po.items.length} item(s)', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                if ((po.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(po.notes!, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          if (po.status == 'HOLD' && (po.holdReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
              child: Text('On hold: ${po.holdReason}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF5B21B6), fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 14),
          // Items table
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: const Row(
                    children: [
                      Expanded(flex: 5, child: Text('ITEM', style: _thStyle)),
                      Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.right, style: _thStyle)),
                      Expanded(flex: 3, child: Text('RATE', textAlign: TextAlign.right, style: _thStyle)),
                      Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: _thStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...po.items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text(it.description, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                          Expanded(flex: 2, child: Text('${fmtQty(it.quantity)} ${it.unit}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
                          Expanded(flex: 3, child: Text(CurrencyUtils.format(it.rate), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
                          Expanded(flex: 3, child: Text(CurrencyUtils.format(it.amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                        ],
                      ),
                    )),
                if (po.items.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No line items.', style: TextStyle(color: AppColors.textMuted))),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    children: [
                      _totalRow('Subtotal', po.subtotal),
                      const SizedBox(height: 4),
                      _totalRow('GST', po.gstAmount),
                      const SizedBox(height: 6),
                      _totalRow('Total', po.totalAmount, bold: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: bold ? AppColors.textPrimary : AppColors.textSecondary)),
          Text(CurrencyUtils.format(value), style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: AppColors.textPrimary)),
        ],
      );
}

const _thStyle = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3);

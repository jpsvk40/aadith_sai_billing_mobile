import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/vendor_purchase_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/purchase_detail_provider.dart';

const _pOrange = Color(0xFFF59E0B);

/// A vendor purchase bill with its line items. Opened from the Purchases list.
class PurchaseDetailScreen extends ConsumerWidget {
  final String purchaseId;
  const PurchaseDetailScreen({super.key, required this.purchaseId});

  Color _statusColor(String s) => switch (s) {
        'PAID' => AppColors.success,
        'PARTIALLY_PAID' => _pOrange,
        'CANCELLED' => AppColors.danger,
        _ => const Color(0xFFEAB308),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseDetailProvider(purchaseId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Purchase Detail')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.refresh(purchaseDetailProvider(purchaseId))),
        data: (p) => RefreshIndicator(
          onRefresh: () async => ref.refresh(purchaseDetailProvider(purchaseId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _headerCard(p),
              const SizedBox(height: 14),
              _amountBoxes(p),
              const SizedBox(height: 18),
              if (p.items.isNotEmpty) _itemsSection(p) else _noItems(),
              const SizedBox(height: 14),
              _totalsCard(p),
              if ((p.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                _notesCard(p.notes!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  Widget _headerCard(VendorPurchase p) {
    final sc = _statusColor(p.status);
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(p.purchaseNumber, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
                  child: Text(p.status.replaceAll('_', ' '), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
                ),
              ],
            ),
            if (p.vendorName != null) ...[
              const SizedBox(height: 8),
              Text(p.vendorName!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
            if ((p.vendorGstin ?? '').isNotEmpty)
              Text('GSTIN ${p.vendorGstin}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            Wrap(spacing: 18, runSpacing: 6, children: [
              if (p.invoiceNumber != null) _kv('Vendor Inv #', p.invoiceNumber!),
              _kv('Purchase date', AppDateUtils.formatDisplay(p.purchaseDate ?? p.invoiceDate)),
              if (p.invoiceDate != null) _kv('Invoice date', AppDateUtils.formatDisplay(p.invoiceDate)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      );

  Widget _amountBoxes(VendorPurchase p) => Row(children: [
        _amountBox('Total', p.totalAmount, AppColors.textPrimary),
        const SizedBox(width: 10),
        _amountBox('Paid', p.paidAmount, AppColors.success),
        const SizedBox(width: 10),
        _amountBox('Outstanding', p.outstandingAmount, p.outstandingAmount > 0 ? AppColors.danger : AppColors.success),
      ]);

  Widget _amountBox(String label, double value, Color color) => Expanded(
        child: _card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Column(children: [
              Text(CurrencyUtils.format(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

  Widget _itemsSection(VendorPurchase p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items (${p.items.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: List.generate(p.items.length, (i) {
                final it = p.items[i];
                final last = i == p.items.length - 1;
                final qtyStr = it.quantity == it.quantity.roundToDouble() ? it.quantity.toStringAsFixed(0) : it.quantity.toString();
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: last ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.description, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    '$qtyStr ${it.unit} × ${CurrencyUtils.format(it.unitPrice)}',
                                    if ((it.hsnCode ?? '').isNotEmpty) 'HSN ${it.hsnCode}',
                                    if (it.taxPercent > 0) 'GST ${it.taxPercent.toStringAsFixed(it.taxPercent % 1 == 0 ? 0 : 1)}%',
                                  ].join('  ·  '),
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                                if (it.discountAmount > 0)
                                  Text('Discount −${CurrencyUtils.format(it.discountAmount)}', style: const TextStyle(fontSize: 11, color: _pOrange)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(CurrencyUtils.format(it.lineTotal), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      );

  Widget _noItems() => _card(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Center(child: Text('No itemised lines on this bill', style: TextStyle(color: AppColors.textSecondary))),
        ),
      );

  Widget _totalsCard(VendorPurchase p) => _card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _totalRow('Taxable value', p.taxableAmount),
            if (p.discountTotal > 0) _totalRow('Discount', -p.discountTotal),
            if (p.cgstAmount > 0) _totalRow('CGST', p.cgstAmount),
            if (p.sgstAmount > 0) _totalRow('SGST', p.sgstAmount),
            if (p.igstAmount > 0) _totalRow('IGST', p.igstAmount),
            if (p.cgstAmount == 0 && p.sgstAmount == 0 && p.igstAmount == 0 && p.gstAmount > 0) _totalRow('GST', p.gstAmount),
            if (p.freightCharges > 0) _totalRow('Freight', p.freightCharges),
            if (p.miscCharges > 0) _totalRow('Misc charges', p.miscCharges),
            if (p.roundOff != 0) _totalRow('Round off', p.roundOff),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: AppColors.border)),
            _totalRow('Grand total', p.totalAmount, bold: true),
          ]),
        ),
      );

  Widget _totalRow(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: bold ? AppColors.textPrimary : AppColors.textSecondary)),
            Text(CurrencyUtils.format(value), style: TextStyle(fontSize: bold ? 15 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
      );

  Widget _notesCard(String notes) => _card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(notes, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ]),
        ),
      );
}

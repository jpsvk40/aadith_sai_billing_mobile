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

/// RFQ detail — read-only view of the enquiry: items, invited vendors, and the
/// quotations received (with the winning quote highlighted). Recording quotes /
/// selecting a winner / converting to PO stay on the web.
class RfqDetailScreen extends ConsumerWidget {
  const RfqDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rfqDetailProvider(id));
    final vendorNames = ref.watch(procurementVendorNamesProvider).valueOrNull ?? const <int, String>{};
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('RFQ')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(rfqDetailProvider(id))),
        data: (rfq) => _body(context, ref, rfq, vendorNames),
      ),
    );
  }

  String _vname(Map<int, String> names, int vid) => names[vid] ?? 'Vendor #$vid';

  Widget _body(BuildContext context, WidgetRef ref, Rfq rfq, Map<int, String> names) {
    final quotedVendorIds = rfq.quotations.map((q) => q.vendorId).toSet();
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(rfqDetailProvider(id)),
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
                    Expanded(child: Text(rfq.rfqNumber.isEmpty ? 'RFQ' : rfq.rfqNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                    ProcStatusPill(rfq.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${AppDateUtils.formatDisplay(rfq.rfqDate)}  ·  ${rfq.items.length} item(s)  ·  ${rfq.vendors.length} vendor(s)  ·  ${rfq.quotations.length} quote(s)',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Items'),
          const SizedBox(height: 8),
          _card(rfq.items.isEmpty
              ? [_muted('No items on this RFQ.')]
              : rfq.items
                  .map((it) => _lineRow(it.itemDescription, '${fmtQty(it.quantity)} ${it.unit}'))
                  .toList()),
          const SizedBox(height: 14),
          _sectionTitle('Vendors & Quotations'),
          const SizedBox(height: 8),
          _card(rfq.vendors.isEmpty
              ? [_muted('No vendors invited.')]
              : rfq.vendors.map((v) {
                  final quoted = quotedVendorIds.contains(v.vendorId);
                  return _lineRow(
                    _vname(names, v.vendorId),
                    quoted ? 'quoted' : 'awaiting',
                    trailingColor: quoted ? AppColors.success : AppColors.textMuted,
                  );
                }).toList()),
          if (rfq.quotations.isNotEmpty) ...[
            const SizedBox(height: 14),
            _sectionTitle('Quotes received'),
            const SizedBox(height: 8),
            _card(rfq.quotations.map((q) {
              final selected = q.status == 'SELECTED' || rfq.selectedQuotationId == q.id;
              return Container(
                color: selected ? AppColors.success.withValues(alpha: 0.07) : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_vname(names, q.vendorId), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if (q.deliveryDays != null)
                            Text('${q.deliveryDays}d delivery', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(CurrencyUtils.format(q.totalAmount), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: selected ? AppColors.success : AppColors.textPrimary)),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                    ],
                  ],
                ),
              );
            }).toList()),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: AppColors.textSecondary));

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              children[i],
            ],
          ],
        ),
      );

  Widget _lineRow(String left, String right, {Color? trailingColor}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(child: Text(left, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary))),
            const SizedBox(width: 8),
            Text(right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: trailingColor ?? AppColors.textSecondary)),
          ],
        ),
      );

  Widget _muted(String text) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
      );
}

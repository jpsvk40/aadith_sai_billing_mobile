import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/vendor_payment_model.dart';
import '../providers/vendor_payment_providers.dart';

/// Vendor payments made — merged single-bill + bulk FIFO rows, most recent first.
class VendorPaymentListScreen extends ConsumerWidget {
  const VendorPaymentListScreen({super.key});

  String _shortDate(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);

  Color _modeColor(String? m) {
    switch (m) {
      case 'Cash':
        return const Color(0xFF059669);
      case 'UPI':
        return const Color(0xFF7C3AED);
      case 'Cheque':
        return const Color(0xFFD97706);
      default:
        return AppColors.primary; // Bank Transfer
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorPaymentsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vendor Payments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/finance/payables/pay');
          ref.invalidate(vendorPaymentsProvider);
        },
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Pay vendor'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: const TextStyle(color: AppColors.danger)))),
        data: (rows) {
          final total = rows.fold<double>(0, (a, r) => a + r.amount);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vendorPaymentsProvider),
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total paid', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(CurrencyUtils.format(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    ])),
                    Text('${rows.length} payment${rows.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No vendor payments yet.', style: TextStyle(color: AppColors.textSecondary))))
                else
                  ...rows.map(_row),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(VendorPaymentRow r) {
    final mc = _modeColor(r.paymentMode);
    final subtitle = r.isBulk
        ? (r.allocationLabels.isEmpty ? 'Bulk payment' : 'Bulk · ${r.allocationLabels.take(3).join(', ')}${r.allocationLabels.length > 3 ? '…' : ''}')
        : [r.purchaseNumber, r.invoiceNumber].where((e) => e != null && e.isNotEmpty).join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(r.vendorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
            if (r.isBulk) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
                child: const Text('BULK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            Text(_shortDate(r.paymentDate), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            const SizedBox(width: 8),
            if (r.paymentMode != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: mc.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(5)),
                child: Text(r.paymentMode!, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: mc)),
              ),
            if (r.chequeStatus != null) ...[
              const SizedBox(width: 6),
              Text(r.chequeStatus!, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ]),
        ])),
        const SizedBox(width: 8),
        Text(CurrencyUtils.format(r.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ]),
    );
  }
}

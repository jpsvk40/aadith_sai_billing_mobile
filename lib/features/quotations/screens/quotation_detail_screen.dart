import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/quotation_model.dart';
import '../providers/quotation_providers.dart';

/// Quotation detail — status transitions + convert-to-invoice + read-only lines,
/// mirroring the web QuotationsPage detail modal.
class QuotationDetailScreen extends ConsumerStatefulWidget {
  final String quotationId;
  const QuotationDetailScreen({super.key, required this.quotationId});
  @override
  ConsumerState<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends ConsumerState<QuotationDetailScreen> {
  bool _busy = false;

  int get _id => int.parse(widget.quotationId);

  void _refresh() {
    ref.invalidate(quotationDetailProvider(_id));
    ref.read(quotationListProvider.notifier).load();
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (success != null) _snack(success);
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success));
  }

  Future<void> _setStatus(String status) => _run(
        () => ref.read(quotationRepositoryProvider).updateStatus(_id, status),
        success: 'Marked $status',
      );

  Future<void> _convert(Quotation q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to invoice?'),
        content: Text('Create a GST invoice from ${q.quoteNumber} (${CurrencyUtils.format(q.total)}). This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Convert')),
        ],
      ),
    );
    if (confirm != true) return;
    await _run(() async {
      final res = await ref.read(quotationRepositoryProvider).convertToInvoice(_id);
      final no = res['invoiceNo'] ?? res['invoiceId'];
      _snack('Invoice $no created');
    });
  }

  String _shortDate(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quotationDetailProvider(_id));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Quotation')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: const TextStyle(color: AppColors.danger)))),
        data: (q) => _body(q),
      ),
    );
  }

  Widget _body(Quotation q) {
    final c = QuotationStatus.color(q.status);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(q.quoteNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(q.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(q.partyLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              'Quote ${_shortDate(q.quoteDate)}${q.validUntil != null ? '  ·  valid till ${_shortDate(q.validUntil)}' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (q.isConverted) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    q.convertedInvoiceId != null ? 'Invoiced · view invoice' : 'Invoiced',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                  if (q.convertedInvoiceId != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => context.push('/invoices/${q.convertedInvoiceId}'),
                      child: const Icon(Icons.open_in_new, size: 15, color: AppColors.success),
                    ),
                  ],
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        // ── Actions: status transitions + convert ──
        if (!q.isLocked) ...[
          const Text('Update status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in QuotationStatus.settable)
                if (s != q.status)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _setStatus(s),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: QuotationStatus.color(s),
                      side: BorderSide(color: QuotationStatus.color(s)),
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text('→ $s'),
                  ),
            ],
          ),
          if (q.canConvert) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _convert(q),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Convert to invoice'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 13)),
              ),
            ),
          ] else if (q.status == 'ACCEPTED' && q.customerId == null && q.convertedInvoiceId == null) ...[
            const SizedBox(height: 10),
            const Text('Link a customer to this quote before converting to an invoice.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 16),
        ],

        // ── Lines ──
        const Text('Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            for (int i = 0; i < q.lines.length; i++) _lineRow(q.lines[i], i, q.lines.length),
          ]),
        ),
        const SizedBox(height: 14),
        _totalsCard(q),
        if (q.terms != null && q.terms!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Terms / notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Text(q.terms!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _lineRow(QuotationLine l, int i, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: i == count - 1 ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text(
              '${_trim(l.quantity)} × ${CurrencyUtils.format(l.rate)}  ·  GST ${_trim(l.taxPercent)}%',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
          Text(CurrencyUtils.format(l.lineTotal > 0 ? l.lineTotal : (l.quantity * l.rate) * (1 + l.taxPercent / 100)),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
      ]),
    );
  }

  Widget _totalsCard(Quotation q) {
    Widget row(String label, double value, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? AppColors.textSecondary)),
            Text(CurrencyUtils.format(value), style: TextStyle(fontSize: bold ? 16 : 12.5, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color ?? AppColors.textPrimary)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        row('Subtotal', q.subtotal),
        if (q.taxAmount > 0) row('GST', q.taxAmount),
        const Divider(height: 18),
        row('Total', q.total, bold: true, color: AppColors.primary),
      ]),
    );
  }

  String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

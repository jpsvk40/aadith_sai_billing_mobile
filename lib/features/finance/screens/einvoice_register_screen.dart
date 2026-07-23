import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/gst_compliance_model.dart';
import '../providers/gst_compliance_providers.dart';

/// Company-wide e-Invoice (IRN) register — parity with the web EinvoiceRegister page.
/// Clickable KPI tiles (Total / Generated / Pending / Failed / Cancelled) filter the
/// list client-side; each row shows the invoice, IRN (tap-to-copy) and Ack no.
class EinvoiceRegisterScreen extends ConsumerStatefulWidget {
  const EinvoiceRegisterScreen({super.key});
  @override
  ConsumerState<EinvoiceRegisterScreen> createState() => _EinvoiceRegisterScreenState();
}

class _EinvoiceRegisterScreenState extends ConsumerState<EinvoiceRegisterScreen> {
  String _filter = 'All'; // All | GENERATED | PENDING | FAILED | CANCELLED

  String _shortDate(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);

  void _copyIrn(String irn) {
    Clipboard.setData(ClipboardData(text: irn));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('IRN copied'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(einvoiceRegisterProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('e-Invoice Register')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error('$e'),
        data: (docs) {
          final total = docs.length;
          final generated = docs.where((d) => d.status == 'GENERATED').length;
          final pending = docs.where((d) => d.status == 'PENDING').length;
          final failed = docs.where((d) => d.status == 'FAILED').length;
          final cancelled = docs.where((d) => d.status == 'CANCELLED').length;
          final rows = _filter == 'All' ? docs : docs.where((d) => d.status == _filter).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(einvoiceRegisterProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                SizedBox(
                  height: 82,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _kpi('Total IRNs', total, 'All', AppColors.primary),
                      _kpi('Generated', generated, 'GENERATED', EinvoiceStatus.color('GENERATED')),
                      _kpi('Pending', pending, 'PENDING', EinvoiceStatus.color('PENDING')),
                      _kpi('Failed', failed, 'FAILED', EinvoiceStatus.color('FAILED')),
                      _kpi('Cancelled', cancelled, 'CANCELLED', EinvoiceStatus.color('CANCELLED')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        _filter == 'All' ? 'No e-Invoices yet.' : 'No ${_filter.toLowerCase()} e-Invoices.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ...rows.map(_row),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpi(String label, int count, String key, Color color) {
    final active = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        width: 112,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? color : AppColors.border, width: active ? 1.4 : 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _row(EinvoiceDoc d) {
    final inv = d.invoice;
    final c = EinvoiceStatus.color(d.status);
    final irn = d.irn ?? '';
    final irnShort = irn.length > 16 ? '${irn.substring(0, 16)}…' : irn;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(inv?.displayNo ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
          const SizedBox(width: 8),
          _chip(d.status, c),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text(inv?.customerName ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          Text(CurrencyUtils.format(inv?.grandTotal ?? 0), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 3),
        Row(children: [
          Text(_shortDate(inv?.invoiceDate), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          if (d.ackNumber != null && d.ackNumber!.isNotEmpty) ...[
            const Spacer(),
            Text('Ack ${d.ackNumber}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          ],
        ]),
        if (irn.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _copyIrn(irn),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.copy_outlined, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(irnShort, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 0.2))),
                const Text('Tap to copy', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
              ]),
            ),
          ),
        ],
        if (d.status == 'FAILED' && d.errorDetails != null && d.errorDetails!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(d.errorDetails!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.danger)),
        ],
      ]),
    );
  }

  Widget _chip(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
      );

  Widget _error(String e) => ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
          const SizedBox(height: 12),
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
          Center(child: TextButton(onPressed: () => ref.invalidate(einvoiceRegisterProvider), child: const Text('Retry'))),
        ],
      );
}

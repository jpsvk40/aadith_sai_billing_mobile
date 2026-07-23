import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/gst_compliance_model.dart';
import '../providers/gst_compliance_providers.dart';

/// GST Returns review (GSTR-1 / Tally) — parity with the web returns-review page.
/// Month navigator drives a `fromDate/toDate` window; shows summary cards, the
/// validation findings (blockers + warnings) and the final GSTR-1 rows.
class GstReturnsReviewScreen extends ConsumerStatefulWidget {
  const GstReturnsReviewScreen({super.key});
  @override
  ConsumerState<GstReturnsReviewScreen> createState() => _GstReturnsReviewScreenState();
}

class _GstReturnsReviewScreenState extends ConsumerState<GstReturnsReviewScreen> {
  late DateTime _month; // first day of the selected month

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final from = _month;
    final to = DateTime(_month.year, _month.month + 1, 0); // last day of month
    final range = (from: _d(from), to: _d(to));
    final async = ref.watch(gstReturnsReviewProvider(range));
    final isCurrentMonth = _month.year == DateTime.now().year && _month.month == DateTime.now().month;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('GST Returns Review')),
      body: Column(children: [
        // Month navigator
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftMonth(-1)),
            Expanded(child: Center(child: Text('${_monthNames[_month.month - 1]} ${_month.year}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: isCurrentMonth ? null : () => _shiftMonth(1)),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _error('$e', range),
            data: (r) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(gstReturnsReviewProvider(range)),
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _hero(r),
                  const SizedBox(height: 14),
                  const Text('Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _valueCard('B2B', r.b2b.count, r.b2b.value, const Color(0xFF2563EB))),
                    const SizedBox(width: 10),
                    Expanded(child: _valueCard('B2C', r.b2c.count, r.b2c.value, const Color(0xFF16A34A))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _countCard('B2C Small', r.b2csCount, const Color(0xFF9333EA))),
                    const SizedBox(width: 10),
                    Expanded(child: _countCard('B2C Large', r.b2clCount, const Color(0xFF0891B2))),
                  ]),
                  const SizedBox(height: 18),
                  _validations(r),
                  const SizedBox(height: 18),
                  const Text('GSTR-1 rows', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  _finalRowsTable(r.finalRows),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // Hero — total invoices + GSTIN.
  Widget _hero(GstReturnsReview r) {
    final gstin = (r.companyGstin?.isNotEmpty == true) ? r.companyGstin! : (r.supplierGstin ?? '');
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0891B2), Color(0xFF0E7490)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(children: [
          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Invoices in return period', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(height: 4),
            Text('${r.totalInvoices}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.description_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: 5),
              Text('HSN B2B ${r.hsnB2bCount} · B2C ${r.hsnB2cCount}', style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (gstin.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                  child: Text(gstin, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _valueCard(String title, int count, double value, Color color) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 6),
          Text(CurrencyUtils.format(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('$count invoice${count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      );

  Widget _countCard(String title, int count, Color color) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 6),
          Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('invoice${count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      );

  Widget _validations(GstReturnsReview r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Validations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        _summaryPill('${r.blockers} blocker${r.blockers == 1 ? '' : 's'}', const Color(0xFFDC2626)),
        const SizedBox(width: 6),
        _summaryPill('${r.warnings} warning${r.warnings == 1 ? '' : 's'}', const Color(0xFFF59E0B)),
      ]),
      const SizedBox(height: 10),
      if (r.validations.isEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
          child: const Row(children: [
            Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF16A34A)),
            SizedBox(width: 10),
            Expanded(child: Text('No validation issues for this period.', style: TextStyle(fontSize: 12.5, color: Color(0xFF166534)))),
          ]),
        )
      else
        ...r.validations.map(_validationRow),
    ]);
  }

  Widget _validationRow(GstValidation v) {
    final c = v.isBlocker ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // coloured left rail to read severity at a glance
        Container(width: 4, height: 40, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _summaryPill(v.isBlocker ? 'BLOCKER' : 'WARNING', c),
            if (v.invoiceNumber != null && v.invoiceNumber!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(child: Text(v.invoiceNumber!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
            ],
          ]),
          const SizedBox(height: 4),
          Text(v.message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (v.code != null && v.code!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(v.code!, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          ],
        ])),
      ]),
    );
  }

  Widget _summaryPill(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
      );

  Widget _finalRowsTable(List<GstReturnRow> rows) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: const Text('No GSTR-1 rows for this period.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 46,
            horizontalMargin: 12,
            columnSpacing: 18,
            headingTextStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
            dataTextStyle: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
            columns: const [
              DataColumn(label: Text('Section')),
              DataColumn(label: Text('State')),
              DataColumn(label: Text('Taxable'), numeric: true),
              DataColumn(label: Text('Tax %'), numeric: true),
              DataColumn(label: Text('IGST'), numeric: true),
              DataColumn(label: Text('CGST'), numeric: true),
              DataColumn(label: Text('SGST'), numeric: true),
              DataColumn(label: Text('Total'), numeric: true),
            ],
            rows: rows
                .map((r) => DataRow(cells: [
                      DataCell(Text(r.section)),
                      DataCell(Text(r.state)),
                      DataCell(Text(CurrencyUtils.formatCompact(r.taxableValue))),
                      DataCell(Text(r.taxPercent.isEmpty ? '—' : r.taxPercent)),
                      DataCell(Text(CurrencyUtils.formatCompact(r.igst))),
                      DataCell(Text(CurrencyUtils.formatCompact(r.cgst))),
                      DataCell(Text(CurrencyUtils.formatCompact(r.sgst))),
                      DataCell(Text(CurrencyUtils.formatCompact(r.total), style: const TextStyle(fontWeight: FontWeight.w800))),
                    ]))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _error(String e, GstReviewRange range) => ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
          const SizedBox(height: 12),
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
          Center(child: TextButton(onPressed: () => ref.invalidate(gstReturnsReviewProvider(range)), child: const Text('Retry'))),
        ],
      );
}

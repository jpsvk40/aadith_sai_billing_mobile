import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _green = Color(0xFF059669);

/// One payroll run's wage sheet — every employee with rate, attendance,
/// gross, deductions and net (same columns as the web wage sheet).
class PayrollRunDetailScreen extends ConsumerStatefulWidget {
  const PayrollRunDetailScreen({super.key, required this.runId});
  final String runId;

  @override
  ConsumerState<PayrollRunDetailScreen> createState() => _PayrollRunDetailScreenState();
}

class _PayrollRunDetailScreenState extends ConsumerState<PayrollRunDetailScreen> {
  Map<String, dynamic>? _run;
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get('${ApiConstants.payrollRuns}/${widget.runId}');
      if (!mounted) return;
      setState(() {
        _run = data is Map ? data.cast<String, dynamic>() : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _items =>
      ((_run?['items'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  Color _statusColor(String s) => switch (s.toUpperCase()) {
        'PAID' || 'COMPLETED' || 'POSTED' => _green,
        'GENERATED' || 'DRAFT' => const Color(0xFF2563EB),
        'APPROVED' => const Color(0xFF7C3AED),
        'CANCELLED' => const Color(0xFFEF4444),
        _ => AppColors.textSecondary,
      };

  String _fmtDays(dynamic v) {
    final d = _num(v);
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final items = _items;
    final q = _search.trim().toLowerCase();
    final filtered = q.isEmpty
        ? items
        : items.where((it) {
            final emp = (it['employee'] as Map?)?.cast<String, dynamic>() ?? const {};
            return (emp['fullName'] ?? '').toString().toLowerCase().contains(q) ||
                (emp['employeeCode'] ?? '').toString().toLowerCase().contains(q);
          }).toList();

    double gross = 0, net = 0, deductions = 0;
    for (final it in items) {
      gross += _num(it['grossAmount']);
      net += _num(it['netAmount']);
    }
    deductions = gross - net;

    final status = (run?['status'] ?? '').toString();
    final sc = _statusColor(status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(run?['periodLabel']?.toString() ?? 'Payroll run')),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    // ── Hero: run summary ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_green, Color(0xFF047857)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                        child: Stack(children: [
                          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text('${run?['runType'] ?? ''} · ${items.length} employee${items.length == 1 ? '' : 's'}',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(7)),
                                child: Text(status, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text(CurrencyUtils.format(net), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                            Text('Net payout', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Row(children: [
                              _heroMetric('Gross', CurrencyUtils.format(gross)),
                              _heroMetric('Deductions', CurrencyUtils.format(deductions)),
                            ]),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ── Search ──
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search employee name or code…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Employees (${filtered.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    if (filtered.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No employees in this run', style: TextStyle(color: AppColors.textSecondary)))),
                    ...filtered.map((it) => _employeeCard(it, sc)),
                  ]),
                ),
    );
  }

  Widget _heroMetric(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      );

  Widget _employeeCard(Map<String, dynamic> it, Color statusColor) {
    final emp = (it['employee'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = (emp['fullName'] ?? 'Employee').toString();
    final code = (emp['employeeCode'] ?? '').toString();
    final wageType = (it['wageType'] ?? '').toString().toUpperCase();
    final isWeekly = wageType == 'WEEKLY';
    final rate = isWeekly ? _num(it['dailyRate']) : _num(it['monthlyRate']);
    final rateLabel = rate > 0 ? '${CurrencyUtils.format(rate)}${isWeekly ? '/day' : '/month'}' : null;
    final grossAmt = _num(it['grossAmount']);
    final advance = _num(it['advanceDeduction']);
    final netAmt = _num(it['netAmount']);

    // Structured (STAFF) statutory deductions — shown only when present.
    final statutory = <(String, double)>[
      ('PF', _num(it['pfEmployee'])),
      ('ESI', _num(it['esiEmployee'])),
      ('PT', _num(it['pt'])),
      ('TDS', _num(it['tds'])),
      ('Loan', _num(it['loanRecovery'])),
      ('Other', _num(it['otherDeductions'])),
    ].where((d) => d.$2 > 0).toList();

    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40, alignment: Alignment.center,
            decoration: BoxDecoration(color: _green.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _green)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text([if (code.isNotEmpty) code, if (rateLabel != null) rateLabel].join(' · '),
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
            child: Text(isWeekly ? 'WEEKLY' : wageType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
          ),
        ]),
        const SizedBox(height: 10),
        // Attendance strip — same columns as the web wage sheet.
        Wrap(spacing: 6, runSpacing: 6, children: [
          _dayChip('Present', it['presentDays']),
          if (_num(it['halfDays']) > 0) _dayChip('Half', it['halfDays']),
          if (_num(it['paidWeeklyOffs']) > 0) _dayChip('Paid offs', it['paidWeeklyOffs']),
          if (_num(it['paidHolidays']) > 0) _dayChip('Holidays', it['paidHolidays']),
          if (_num(it['absentDays']) > 0) _dayChip('Absent', it['absentDays'], warn: true),
          _dayChip('Payable', it['payableDays'], strong: true),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 10),
        Row(children: [
          _metric('Gross', CurrencyUtils.format(grossAmt)),
          _metric(advance > 0 ? 'Advance ded.' : 'Deductions', CurrencyUtils.format(grossAmt - netAmt)),
          _metric('Net pay', CurrencyUtils.format(netAmt), color: _green),
        ]),
        if (statutory.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: statutory
              .map((d) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(7)),
                    child: Text('${d.$1} ${CurrencyUtils.format(d.$2)}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                  ))
              .toList()),
        ],
        if ((it['remarks'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(it['remarks'].toString(), style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }

  Widget _dayChip(String label, dynamic value, {bool warn = false, bool strong = false}) {
    final color = warn ? const Color(0xFFD97706) : strong ? _green : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? _green.withValues(alpha: 0.10) : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: strong ? _green.withValues(alpha: 0.35) : AppColors.border, width: 0.5),
      ),
      child: Text('$label ${_fmtDays(value)}', style: TextStyle(fontSize: 10.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: color)),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary)),
        ]),
      );
}

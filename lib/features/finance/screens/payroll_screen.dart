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

/// Payroll runs (read) — period, status, headcount and net payout per run
/// (net computed from run items; the API doesn't return a run-level total).
class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});
  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  List<Map<String, dynamic>> _runs = const [];
  bool _loading = true;
  String? _error;

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
      final data = await client.get(ApiConstants.payrollRuns);
      dynamic list = data is Map ? (data['data'] ?? data['runs'] ?? data['rows'] ?? const []) : data;
      if (!mounted) return;
      setState(() {
        _runs = (list is List ? list : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  (double net, double gross, int heads) _totals(Map<String, dynamic> run) {
    final items = ((run['items'] as List?) ?? const []).whereType<Map>().toList();
    double net = 0, gross = 0;
    for (final it in items) {
      net += _num(it['netAmount']);
      gross += _num(it['grossAmount']);
    }
    return (net, gross, items.length);
  }

  Color _statusColor(String s) => switch (s.toUpperCase()) {
        'PAID' || 'COMPLETED' || 'POSTED' => _green,
        'GENERATED' || 'DRAFT' => const Color(0xFF2563EB),
        'APPROVED' => const Color(0xFF7C3AED),
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final latest = _runs.isNotEmpty ? _totals(_runs.first) : (0.0, 0.0, 0);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Payroll')),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_green, Color(0xFF047857)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                        child: Stack(children: [
                          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_runs.isEmpty ? 'Payroll' : 'Latest run — net payout', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                            const SizedBox(height: 4),
                            Text(CurrencyUtils.format(latest.$1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text('${_runs.length} run${_runs.length == 1 ? '' : 's'}${_runs.isNotEmpty ? ' · ${latest.$3} employees in latest' : ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Runs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    if (_runs.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No payroll runs yet', style: TextStyle(color: AppColors.textSecondary)))),
                    ..._runs.map((r) {
                      final t = _totals(r);
                      final status = (r['status'] ?? '').toString();
                      final sc = _statusColor(status);
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
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: _green.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
                              child: const Icon(Icons.groups_outlined, color: _green, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r['periodLabel']?.toString() ?? 'Run #${r['id']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text('${r['runType'] ?? ''} · ${t.$3} employee${t.$3 == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                              child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sc)),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            _metric('Gross', CurrencyUtils.format(t.$2)),
                            _metric('Net payout', CurrencyUtils.format(t.$1)),
                            _metric('Deductions', CurrencyUtils.format(t.$2 - t.$1)),
                          ]),
                        ]),
                      );
                    }),
                  ]),
                ),
    );
  }

  Widget _metric(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
      );
}

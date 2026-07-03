import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

/// Employee Self-Service home — payslips, leave balance, apply leave. The landing surface
/// for the `employee` persona (module `ess`).
class EssScreen extends ConsumerStatefulWidget {
  const EssScreen({super.key});
  @override
  ConsumerState<EssScreen> createState() => _EssScreenState();
}

class _EssScreenState extends ConsumerState<EssScreen> {
  List<Map<String, dynamic>> _payslips = const [];
  List<Map<String, dynamic>> _leave = const [];
  // /api/ess/leave-balance → [{leaveType:{id,name,code}, opening, allotted, taken, balance}]
  List<Map<String, dynamic>> _leaveBalances = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  List<Map<String, dynamic>> _list(dynamic data) {
    dynamic l = data is Map ? (data['data'] ?? data['rows'] ?? data.values.firstWhere((v) => v is List, orElse: () => const [])) : data;
    return (l is List ? l : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _client.get(ApiConstants.essPayslips).catchError((_) => const []),
        _client.get(ApiConstants.essLeaveBalance).catchError((_) => const []),
        _client.get(ApiConstants.essLeave).catchError((_) => const []),
      ]);
      if (!mounted) return;
      setState(() {
        _payslips = _list(results[0]);
        _leaveBalances = _list(results[1]);
        _leave = _list(results[2]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _applyLeave() async {
    if (_leaveBalances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No leave types configured yet — ask your admin.')));
      return;
    }
    final reason = TextEditingController();
    int? leaveTypeId = (_leaveBalances.first['leaveType'] as Map?)?['id'] as int?;
    var from = DateTime.now();
    var to = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> pick(bool isFrom) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: isFrom ? from : to,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setLocal(() {
                if (isFrom) {
                  from = picked;
                  if (to.isBefore(from)) to = from;
                } else {
                  to = picked.isBefore(from) ? from : picked;
                }
              });
            }
          }

          return AlertDialog(
            title: const Text('Apply for leave'),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                initialValue: leaveTypeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Leave type'),
                items: _leaveBalances.map((b) {
                  final t = (b['leaveType'] as Map?)?.cast<String, dynamic>() ?? const {};
                  return DropdownMenuItem(value: t['id'] as int?, child: Text('${t['name'] ?? t['code'] ?? 'Leave'} (bal ${b['balance'] ?? '—'})', overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) => setLocal(() => leaveTypeId = v),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => pick(true),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'From', suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)),
                  child: Text(_fmt(from)),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => pick(false),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'To', suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)),
                  child: Text(_fmt(to)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: leaveTypeId == null ? null : () => Navigator.pop(ctx, true), child: const Text('Submit')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await _client.post(ApiConstants.essLeave, data: {
        'leaveTypeId': leaveTypeId,
        'fromDate': _fmt(from),
        'toDate': _fmt(to),
        'reason': reason.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request submitted.')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My ESS'), automaticallyImplyLeading: false),
      floatingActionButton: FloatingActionButton.extended(onPressed: _applyLeave, icon: const Icon(Icons.event_busy_outlined), label: const Text('Apply leave')),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Hi, ${(user?.name ?? 'there').split(' ').first} 👋', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 3),
                        Text(user?.companyName ?? '', style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (_leaveBalances.isNotEmpty) ...[
                      const Text('Leave balance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 10, runSpacing: 10, children: _leaveBalances.map((b) {
                        final t = (b['leaveType'] as Map?)?.cast<String, dynamic>() ?? const {};
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t['name']?.toString() ?? t['code']?.toString() ?? 'Leave', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('${b['balance'] ?? 0}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ]),
                        );
                      }).toList()),
                      const SizedBox(height: 18),
                    ],
                    const Text('Payslips', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    if (_payslips.isEmpty) const _EmptyLine('No payslips yet')
                    else ..._payslips.map((p) => _tile(
                          p['period']?.toString() ?? p['month']?.toString() ?? 'Payslip',
                          p['status']?.toString() ?? p['payDate']?.toString(),
                          CurrencyUtils.format(_num(p['netPay'] ?? p['netAmount'] ?? p['amount'])),
                          Icons.receipt_long_outlined,
                        )),
                    const SizedBox(height: 18),
                    const Text('Leave requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    if (_leave.isEmpty) const _EmptyLine('No leave requests')
                    else ..._leave.map((l) {
                      String d(dynamic v) { final s = (v ?? '').toString(); return s.length >= 10 ? s.substring(0, 10) : s; }
                      final type = (l['leaveType'] as Map?)?['name']?.toString();
                      return _tile(
                        '${d(l['fromDate'] ?? l['from'])} → ${d(l['toDate'] ?? l['to'])}',
                        [if (type != null) type, if ((l['reason'] ?? '').toString().isNotEmpty) l['reason'].toString()].join(' · '),
                        l['status']?.toString() ?? 'PENDING',
                        Icons.event_busy_outlined,
                      );
                    }),
                  ]),
                ),
    );
  }

  Widget _tile(String title, String? subtitle, String trailing, IconData icon) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ],
          ])),
          const SizedBox(width: 8),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
        ]),
      );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
      );
}

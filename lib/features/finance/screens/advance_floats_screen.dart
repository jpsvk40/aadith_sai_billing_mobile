import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _violet = Color(0xFF7C3AED);

/// Advance floats (petty-cash advances) — list with spent/balance per float,
/// give a new advance, and close a float with returned cash. Web parity for the
/// "Petty Cash & Advances → Advance Floats" section.
class AdvanceFloatsScreen extends ConsumerStatefulWidget {
  const AdvanceFloatsScreen({super.key});
  @override
  ConsumerState<AdvanceFloatsScreen> createState() => _AdvanceFloatsScreenState();
}

class _AdvanceFloatsScreenState extends ConsumerState<AdvanceFloatsScreen> {
  List<Map<String, dynamic>> _floats = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  String _d(dynamic v) { final s = (v ?? '').toString(); return s.length >= 10 ? s.substring(0, 10) : s; }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _client.get(ApiConstants.advanceFloats);
      if (!mounted) return;
      setState(() {
        _floats = (data is List ? data : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _addFloat() async {
    final title = TextEditingController();
    final givenTo = TextEditingController();
    final givenBy = TextEditingController();
    final amount = TextEditingController();
    final notes = TextEditingController();
    var date = DateTime.now();
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Give advance'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title * — e.g. "Arun\'s field trip advance"')),
            const SizedBox(height: 10),
            TextField(controller: givenTo, decoration: const InputDecoration(labelText: 'Given to *')),
            const SizedBox(height: 10),
            TextField(controller: givenBy, decoration: const InputDecoration(labelText: 'Given by')),
            const SizedBox(height: 10),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₹) *')),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(date.year - 1), lastDate: DateTime.now());
                if (picked != null) setLocal(() => date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date *', suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)),
                child: Text(fmt(date)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Give advance')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _client.post(ApiConstants.advanceFloats, data: {
        'title': title.text.trim(),
        'givenTo': givenTo.text.trim(),
        'givenBy': givenBy.text.trim(),
        'amount': double.tryParse(amount.text.trim()) ?? 0,
        'floatDate': fmt(date),
        'notes': notes.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advance recorded.')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _closeFloat(Map<String, dynamic> f) async {
    final balance = _num(f['balance']);
    final returned = TextEditingController(text: balance > 0 ? balance.toStringAsFixed(balance % 1 == 0 ? 0 : 2) : '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close — ${f['title']}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Spent ${CurrencyUtils.format(_num(f['totalSpent']))} of ${CurrencyUtils.format(_num(f['amount']))}.', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(controller: returned, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unused cash returned (₹)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close float')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _client.post(ApiConstants.advanceFloatClose('${f['id']}'), data: {'returnedAmount': double.tryParse(returned.text.trim()) ?? 0});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Float closed.')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _floats.where((f) => (f['status'] ?? '') == 'Open').toList();
    final outstanding = open.fold<double>(0, (a, f) => a + _num(f['balance']));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Advance Floats')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addFloat, icon: const Icon(Icons.add), label: const Text('Give advance')),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_violet, Color(0xFF6D28D9)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                        child: Stack(children: [
                          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Cash out with staff', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                            const SizedBox(height: 4),
                            Text(CurrencyUtils.format(outstanding), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text('${open.length} open float${open.length == 1 ? '' : 's'} · ${_floats.length} total', style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_floats.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Center(child: Text('No advances yet — give one with the button below.', style: TextStyle(color: AppColors.textSecondary)))),
                    ..._floats.map(_card),
                  ]),
                ),
    );
  }

  Widget _card(Map<String, dynamic> f) {
    final isOpen = (f['status'] ?? '') == 'Open';
    final balance = _num(f['balance']);
    final spent = _num(f['totalSpent']);
    final amount = _num(f['amount']);
    final pct = amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0.0;
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
            decoration: BoxDecoration(color: _violet.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.account_balance_wallet_outlined, color: _violet, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((f['title'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text('${f['givenTo'] ?? ''} · ${_d(f['floatDate'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: (isOpen ? const Color(0xFF16A34A) : AppColors.textSecondary).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Text((f['status'] ?? '').toString(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isOpen ? const Color(0xFF16A34A) : AppColors.textSecondary)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: AppColors.border, color: pct >= 1 ? const Color(0xFFDC2626) : _violet),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _metric('Advance', CurrencyUtils.format(amount)),
          _metric('Spent', CurrencyUtils.format(spent)),
          _metric(isOpen ? 'Balance' : 'Returned', CurrencyUtils.format(isOpen ? balance : _num(f['returnedAmount']))),
        ]),
        if (isOpen) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _closeFloat(f),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(color: _violet.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: _violet.withValues(alpha: 0.35))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.task_alt, size: 15, color: _violet),
                SizedBox(width: 6),
                Text('Close float', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _violet)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _metric(String l, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
      );
}

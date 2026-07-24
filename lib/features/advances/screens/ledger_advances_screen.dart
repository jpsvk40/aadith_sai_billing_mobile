import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/ledger_advance_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/ledger_advances_provider.dart';

const _indigo = Color(0xFF4F46E5);

/// Vendor & Customer LEDGER advances (web `/advances`). Party tabs drive the
/// `?party=VENDOR|CUSTOMER` list; each advance shows amount / adjusted / open
/// balance and can be adjusted against a bill or (if unadjusted) deleted.
///
/// DISTINCT from the petty-cash "Advance Floats" screen (`/finance/advances`).
/// This is the sub-route `/finance/advances/ledger`.
class LedgerAdvancesScreen extends ConsumerStatefulWidget {
  const LedgerAdvancesScreen({super.key});

  @override
  ConsumerState<LedgerAdvancesScreen> createState() => _LedgerAdvancesScreenState();
}

class _LedgerAdvancesScreenState extends ConsumerState<LedgerAdvancesScreen> {
  String _party = 'VENDOR';
  String _statusFilter = 'All'; // All | Open | Adjusted (client-side)
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() => ref.read(ledgerAdvancesProvider.notifier).load(party: _party);

  bool get _isVendor => _party == 'VENDOR';

  List<LedgerAdvance> _visible(List<LedgerAdvance> all) {
    var list = all;
    if (_statusFilter == 'Open') {
      list = list.where((a) => a.isOpen).toList();
    } else if (_statusFilter == 'Adjusted') {
      list = list.where((a) => !a.isOpen).toList();
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((a) =>
              a.displayName.toLowerCase().contains(q) ||
              (a.notes ?? '').toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  // ─────────────────────────── Actions ───────────────────────────

  Future<void> _recordAdvance() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var mode = 'Bank Transfer';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(_isVendor ? 'Advance to vendor' : 'Advance from customer'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: _isVendor ? 'Vendor name *' : 'Customer name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixText: '₹ '),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: const ['Bank Transfer', 'Cash', 'Cheque', 'UPI']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setLocal(() => mode = v ?? 'Bank Transfer'),
              ),
              const SizedBox(height: 10),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record & post')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final amount = CurrencyUtils.parse(amountCtrl.text.trim());
    if (name.isEmpty) {
      _toast('Enter the ${_isVendor ? 'vendor' : 'customer'} name.', error: true);
      return;
    }
    if (amount <= 0) {
      _toast('Amount must be greater than zero.', error: true);
      return;
    }
    try {
      await ref.read(ledgerAdvancesProvider.notifier).create(
            partyName: name,
            amount: amount,
            paymentMode: mode,
            notes: notesCtrl.text.trim(),
          );
      _toast('Advance recorded & posted.');
    } catch (e) {
      _toast('$e', error: true);
    }
  }

  Future<void> _adjust(LedgerAdvance a) async {
    final amountCtrl = TextEditingController(
      text: a.balance % 1 == 0 ? a.balance.toStringAsFixed(0) : a.balance.toStringAsFixed(2),
    );
    final refCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust against bill'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${a.displayName} · open ${CurrencyUtils.format(a.balance)}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Adjust amount (₹) *', prefixText: '₹ '),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: refCtrl,
            decoration: const InputDecoration(labelText: 'Against bill / invoice ref'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Adjust & post')),
        ],
      ),
    );
    if (ok != true) return;

    final amount = CurrencyUtils.parse(amountCtrl.text.trim());
    if (amount <= 0) {
      _toast('Adjustment amount must be greater than zero.', error: true);
      return;
    }
    if (amount > a.balance + 0.01) {
      _toast('Only ${CurrencyUtils.format(a.balance)} is unadjusted on this advance.', error: true);
      return;
    }
    try {
      await ref.read(ledgerAdvancesProvider.notifier).adjust(
            id: a.id,
            amount: amount,
            reference: refCtrl.text.trim(),
          );
      _toast('Adjustment posted.');
    } catch (e) {
      _toast('$e', error: true);
    }
  }

  Future<void> _delete(LedgerAdvance a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete advance?'),
        content: Text('This reverses the posting for ${a.displayName}. Advances with adjustments cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ledgerAdvancesProvider.notifier).remove(a.id);
      _toast('Advance deleted.');
    } catch (e) {
      _toast('$e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : null),
    );
  }

  // ─────────────────────────── Build ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ledgerAdvancesProvider);
    final visible = _visible(state.advances);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vendor & Customer Advances')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _recordAdvance,
        backgroundColor: _indigo,
        icon: const Icon(Icons.add),
        label: const Text('Record Advance'),
      ),
      body: state.isLoading && state.advances.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.advances.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: _reload)
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: visible.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(state, visible.length);
                      return _card(visible[i - 1]);
                    },
                  ),
                ),
    );
  }

  Widget _header(LedgerAdvancesState s, int shown) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero — open balance for the selected party.
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_indigo, Color(0xFF4338CA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Stack(children: [
              Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isVendor ? 'Unadjusted advances to vendors' : 'Unadjusted advances from customers',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 4),
                Text(CurrencyUtils.format(s.openBalance), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 8),
                Text('${s.advances.where((a) => a.isOpen).length} open · ${s.advances.length} total',
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        // Party tabs.
        Row(children: [
          _partyTab('VENDOR', 'Vendor', Icons.north_east),
          const SizedBox(width: 8),
          _partyTab('CUSTOMER', 'Customer', Icons.south_west),
        ]),
        const SizedBox(height: 12),
        // Search.
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: _isVendor ? 'Search vendor, notes...' : 'Search customer, notes...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  })
                : null,
          ),
        ),
        const SizedBox(height: 10),
        // Status filter chips (client-side).
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['All', 'Open', 'Adjusted'].map((f) {
              final sel = f == _statusFilter;
              final c = f == 'Open'
                  ? AppColors.warning
                  : f == 'Adjusted'
                      ? AppColors.success
                      : _indigo;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: sel,
                  onSelected: (_) => setState(() => _statusFilter = f),
                  labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? c : AppColors.textSecondary),
                  selectedColor: c.withValues(alpha: 0.14),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: sel ? c : AppColors.border),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        if (shown == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 44),
            child: Center(child: Text('No advances here — record one with the button below.', style: TextStyle(color: AppColors.textSecondary))),
          ),
      ]),
    );
  }

  Widget _partyTab(String value, String label, IconData icon) {
    final sel = _party == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_party == value) return;
          setState(() => _party = value);
          _reload();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: sel ? _indigo : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? _indigo : AppColors.border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: sel ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('$label Advances',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }

  Widget _card(LedgerAdvance a) {
    final sc = a.isOpen ? AppColors.warning : AppColors.success;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: _indigo.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.savings_outlined, color: _indigo, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text(
                '${AppDateUtils.formatDisplay(a.advanceDate)}${a.paymentMode != null && a.paymentMode!.isNotEmpty ? '  ·  ${a.paymentMode}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ]),
          ),
          _pill(a.status, sc),
        ]),
        if (a.notes != null && a.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(a.notes!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          _metric('Amount', CurrencyUtils.format(a.amount)),
          _metric('Adjusted', CurrencyUtils.format(a.adjustedAmount), color: AppColors.success),
          _metric('Balance', CurrencyUtils.format(a.balance), color: a.balance > 0 ? AppColors.textPrimary : AppColors.textMuted),
        ]),
        if (a.isOpen && a.balance > 0) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _adjust(a),
                icon: const Icon(Icons.playlist_add_check, size: 17),
                label: const Text('Adjust'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _indigo,
                  side: BorderSide(color: _indigo.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _delete(a),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Icon(Icons.delete_outline, size: 18),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _metric(String label, String value, {Color color = AppColors.textPrimary}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
      );

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/vendor_model.dart';
import '../../../data/models/vendor_payment_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/vendor_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/vendor_payment_providers.dart';

/// Record a vendor payment — pick a vendor, review outstanding bills + credit, then
/// record a lump payment (server allocates FIFO; excess → credit). Mirrors the web
/// Vendor Bulk Payment page. Optionally targets specific bills via selection.
class VendorPayScreen extends ConsumerStatefulWidget {
  final String? initialVendorId;
  const VendorPayScreen({super.key, this.initialVendorId});
  @override
  ConsumerState<VendorPayScreen> createState() => _VendorPayScreenState();
}

class _VendorPayScreenState extends ConsumerState<VendorPayScreen> {
  String? _vendorId;
  String? _vendorName;
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _mode = 'Bank Transfer';
  DateTime _date = DateTime.now();
  final Set<int> _selected = {};
  bool _applyCredit = false;
  bool _saving = false;

  late final ApiClient _client;

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    _vendorId = widget.initialVendorId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  String _apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickVendor() async {
    final chosen = await showModalBottomSheet<Vendor>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VendorPicker(repo: VendorRepository(_client)),
    );
    if (chosen != null) {
      setState(() {
        _vendorId = chosen.id;
        _vendorName = chosen.vendorName;
        _selected.clear();
      });
    }
  }

  void _fillFromSelected(VendorLedger ledger) {
    final sum = ledger.outstandingPurchases
        .where((b) => _selected.contains(b.id))
        .fold<double>(0, (a, b) => a + b.outstandingAmount);
    _amountCtrl.text = sum > 0 ? sum.toStringAsFixed(2) : '';
    setState(() {});
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (_vendorId == null) { _snack('Pick a vendor', error: true); return; }
    if (amount <= 0) { _snack('Enter an amount greater than 0', error: true); return; }
    setState(() => _saving = true);
    try {
      final res = await ref.read(vendorPaymentRepositoryProvider).recordBulkPayment(
            vendorId: _vendorId!,
            paymentDate: _apiDate(_date),
            amount: amount,
            paymentMode: _mode,
            referenceNo: _refCtrl.text.trim(),
            remarks: _remarksCtrl.text.trim(),
            applyCredit: _applyCredit,
            selectedPurchaseIds: _selected.toList(),
          );
      if (!mounted) return;
      final closed = res['purchasesClosed'] ?? 0;
      final excess = (res['excessAmount'] is num) ? (res['excessAmount'] as num).toDouble() : 0.0;
      ref.invalidate(vendorLedgerProvider(_vendorId!));
      ref.invalidate(vendorPaymentsProvider);
      _snack('Payment recorded · $closed bill(s) closed${excess > 0 ? ' · ${CurrencyUtils.format(excess)} to credit' : ''}');
      _amountCtrl.clear();
      _refCtrl.clear();
      _remarksCtrl.clear();
      setState(() { _selected.clear(); _applyCredit = false; });
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pay Vendor')),
      body: _vendorId == null ? _vendorPrompt() : _ledgerBody(),
    );
  }

  Widget _vendorPrompt() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.store_mall_directory_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Text('Choose a vendor to record a payment', style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(onPressed: _pickVendor, icon: const Icon(Icons.search), label: const Text('Select vendor')),
          ]),
        ),
      );

  Widget _ledgerBody() {
    final async = ref.watch(vendorLedgerProvider(_vendorId!));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: const TextStyle(color: AppColors.danger)))),
      data: (ledger) => _form(ledger),
    );
  }

  Widget _form(VendorLedger ledger) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Vendor header + change
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            const Icon(Icons.store_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(_vendorName ?? ledger.vendorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
            TextButton(onPressed: _pickVendor, child: const Text('Change')),
          ]),
        ),
        const SizedBox(height: 12),
        // KPIs
        Row(children: [
          Expanded(child: _kpi('Outstanding', ledger.totalOutstanding, AppColors.danger)),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Credit', ledger.creditBalance, AppColors.success)),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Net payable', ledger.netPayable, AppColors.textPrimary)),
        ]),
        if (ledger.creditBalance > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.savings_outlined, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(child: Text('Credit balance ${CurrencyUtils.format(ledger.creditBalance)} available', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
        const SizedBox(height: 18),

        // Outstanding bills (selectable)
        Row(children: [
          const Text('Outstanding bills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Spacer(),
          if (_selected.isNotEmpty)
            TextButton(onPressed: () => _fillFromSelected(ledger), child: Text('Fill ${_selected.length} →')),
        ]),
        const SizedBox(height: 6),
        if (ledger.outstandingPurchases.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('No open bills 🎉', style: TextStyle(color: AppColors.textSecondary)))),
        ...ledger.outstandingPurchases.map((b) => _billTile(b)),
        if (ledger.heldPurchases.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${ledger.heldPurchases.length} bill(s) on payment hold — excluded', style: const TextStyle(fontSize: 11.5, color: AppColors.warning, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 18),

        // Payment form
        const Text('Record payment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _dateField()),
          const SizedBox(width: 12),
          Expanded(child: _amountField()),
        ]),
        const SizedBox(height: 12),
        _modeDropdown(),
        const SizedBox(height: 12),
        TextField(controller: _refCtrl, decoration: _dec('Reference (UTR / Cheque #)')),
        const SizedBox(height: 12),
        TextField(controller: _remarksCtrl, decoration: _dec('Remarks (optional)')),
        if (ledger.creditBalance > 0) ...[
          const SizedBox(height: 6),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            value: _applyCredit,
            onChanged: (v) => setState(() => _applyCredit = v ?? false),
            title: Text('Also apply credit balance of ${CurrencyUtils.format(ledger.creditBalance)}', style: const TextStyle(fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(_saving ? 'Recording…' : 'Confirm & Record Payment'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _kpi(String label, double value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(CurrencyUtils.formatCompact(value), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        ]),
      );

  Widget _billTile(VendorBill b) {
    final selected = _selected.contains(b.id);
    final date = (b.purchaseDate ?? b.invoiceDate ?? '').toString();
    return InkWell(
      onTap: () => setState(() => selected ? _selected.remove(b.id) : _selected.add(b.id)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.4 : 1),
        ),
        child: Row(children: [
          Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, size: 20, color: selected ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.purchaseNumber ?? b.invoiceNumber ?? 'Bill', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            Text('${date.length >= 10 ? date.substring(0, 10) : date} · paid ${CurrencyUtils.format(b.paidAmount)} of ${CurrencyUtils.format(b.totalAmount)}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          ])),
          Text(CurrencyUtils.format(b.outstandingAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.danger)),
        ]),
      ),
    );
  }

  Widget _modeDropdown() => DropdownButtonFormField<String>(
        initialValue: _mode,
        decoration: _dec('Payment mode'),
        items: kPaymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
        onChanged: (v) => setState(() => _mode = v ?? 'Bank Transfer'),
      );

  Widget _amountField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Amount (₹)', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: _dec('0.00'),
          ),
        ],
      );

  Widget _dateField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Date', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(_apiDate(_date), style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ),
        ],
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      );
}

/// Searchable vendor picker (matches the customer-picker pattern).
class _VendorPicker extends StatefulWidget {
  final VendorRepository repo;
  const _VendorPicker({required this.repo});
  @override
  State<_VendorPicker> createState() => _VendorPickerState();
}

class _VendorPickerState extends State<_VendorPicker> {
  List<Vendor> _items = [];
  bool _loading = false;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final items = await widget.repo.getVendors(search: q.isEmpty ? null : q);
      if (mounted) setState(() => _items = items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('Select vendor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(controller: _ctrl, decoration: const InputDecoration(labelText: 'Search', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: _search),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => ListTile(
                        leading: const Icon(Icons.store_outlined),
                        title: Text(_items[i].vendorName),
                        subtitle: _items[i].city != null ? Text(_items[i].city!) : null,
                        onTap: () => Navigator.pop(context, _items[i]),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

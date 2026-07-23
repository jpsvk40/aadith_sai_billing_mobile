import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/credit_note_model.dart';
import '../../../data/models/vendor_model.dart';
import '../../../data/models/vendor_payment_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/vendor_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../finance/providers/vendor_payment_providers.dart';
import '../providers/credit_note_providers.dart';

/// The bill a vendor credit note is raised against — carries the ceiling.
class _TargetBill {
  final int id;
  final String label;
  final double outstanding;
  const _TargetBill(this.id, this.label, this.outstanding);
}

/// Raise a vendor credit note against ONE purchase (lump-sum). If launched with a
/// `vendorPurchaseId` the bill is fixed; otherwise pick a vendor then one of their
/// outstanding bills. Total is hard-capped at the bill's outstanding (client + server).
class VendorCreditNoteCreateScreen extends ConsumerStatefulWidget {
  final int? vendorPurchaseId;
  const VendorCreditNoteCreateScreen({super.key, this.vendorPurchaseId});
  @override
  ConsumerState<VendorCreditNoteCreateScreen> createState() => _VendorCreditNoteCreateScreenState();
}

class _VendorCreditNoteCreateScreenState extends ConsumerState<VendorCreditNoteCreateScreen> {
  final _cnNumberCtrl = TextEditingController();
  final _taxableCtrl = TextEditingController();
  final _gstCtrl = TextEditingController(text: '18');
  final _roundOffCtrl = TextEditingController();

  String? _vendorId;
  String? _vendorName;
  _TargetBill? _target;
  bool _loadingTarget = false;
  String _reason = kVendorCreditNoteReasons.first;
  bool _interState = false;
  DateTime _date = DateTime.now();
  bool _saving = false;

  late final ApiClient _client;

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    if (widget.vendorPurchaseId != null) _loadTargetFromPurchase(widget.vendorPurchaseId!);
  }

  @override
  void dispose() {
    _cnNumberCtrl.dispose();
    _taxableCtrl.dispose();
    _gstCtrl.dispose();
    _roundOffCtrl.dispose();
    super.dispose();
  }

  String _apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  double _r2(double v) => double.parse(v.toStringAsFixed(2));

  double get _taxable => double.tryParse(_taxableCtrl.text.trim()) ?? 0;
  double get _gstPct => double.tryParse(_gstCtrl.text.trim()) ?? 0;
  double get _roundOff => double.tryParse(_roundOffCtrl.text.trim()) ?? 0;
  double get _gstAmt => _taxable * _gstPct / 100;
  double get _cgst => _interState ? 0 : _gstAmt / 2;
  double get _sgst => _interState ? 0 : _gstAmt / 2;
  double get _igst => _interState ? _gstAmt : 0;
  double get _total => _taxable + _cgst + _sgst + _igst + _roundOff;

  Future<void> _loadTargetFromPurchase(int purchaseId) async {
    setState(() => _loadingTarget = true);
    try {
      final t = await ref.read(creditNoteRepositoryProvider).getVendorPurchaseTarget(purchaseId);
      if (!mounted) return;
      if (t != null) {
        setState(() => _target = _TargetBill(purchaseId, t['label'].toString(), (t['outstanding'] as num).toDouble()));
      } else {
        _snack('Could not load that purchase', error: true);
      }
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loadingTarget = false);
    }
  }

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
        _target = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final target = _target;
    if (target == null) {
      _snack('Select the bill this credit note is against', error: true);
      return;
    }
    if (_cnNumberCtrl.text.trim().isEmpty) {
      _snack('Enter the vendor\'s credit note number', error: true);
      return;
    }
    if (_total <= 0) {
      _snack('Enter a taxable amount so the total is greater than 0', error: true);
      return;
    }
    // Hard ceiling: never exceed the bill's outstanding (server also enforces this).
    if (_r2(_total) > _r2(target.outstanding) + 0.01) {
      _snack('Total ${CurrencyUtils.format(_total)} exceeds the outstanding ${CurrencyUtils.format(target.outstanding)}', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final cn = await ref.read(creditNoteRepositoryProvider).createVendorCreditNote({
        'vendorPurchaseId': target.id,
        'creditNoteNumber': _cnNumberCtrl.text.trim(),
        'creditNoteDate': _apiDate(_date),
        'reason': _reason,
        'taxableAmount': _r2(_taxable),
        'cgstAmount': _r2(_cgst),
        'sgstAmount': _r2(_sgst),
        'igstAmount': _r2(_igst),
        'roundOff': _r2(_roundOff),
        'totalAmount': _r2(_total),
      });
      if (!mounted) return;
      ref.invalidate(vendorCreditNoteListProvider);
      if (_vendorId != null) ref.invalidate(vendorLedgerProvider(_vendorId!));
      _snack('Vendor credit note ${cn.creditNoteNumber.isEmpty ? 'saved' : cn.creditNoteNumber} saved');
      context.pop();
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
      appBar: AppBar(title: const Text('Vendor Credit Note')),
      body: _loadingTarget
          ? const Center(child: CircularProgressIndicator())
          : _target != null
              ? _form(_target!)
              : _vendorId == null
                  ? _vendorPrompt()
                  : _billPicker(),
    );
  }

  Widget _vendorPrompt() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.store_mall_directory_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Text('Choose a vendor, then the bill to credit', style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(onPressed: _pickVendor, icon: const Icon(Icons.search), label: const Text('Select vendor')),
          ]),
        ),
      );

  Widget _billPicker() {
    final async = ref.watch(vendorLedgerProvider(_vendorId!));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: const TextStyle(color: AppColors.danger)))),
      data: (ledger) {
        final bills = ledger.outstandingPurchases;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _vendorHeader(_vendorName ?? ledger.vendorName),
            const SizedBox(height: 14),
            const Text('Select the bill to credit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (bills.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No outstanding bills for this vendor.', style: TextStyle(color: AppColors.textSecondary)))),
            ...bills.map(_billTile),
          ],
        );
      },
    );
  }

  Widget _billTile(VendorBill b) {
    final date = (b.purchaseDate ?? b.invoiceDate ?? '').toString();
    return InkWell(
      onTap: () => setState(() => _target = _TargetBill(b.id, b.purchaseNumber ?? b.invoiceNumber ?? 'Bill', b.outstandingAmount)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.description_outlined, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.purchaseNumber ?? b.invoiceNumber ?? 'Bill', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            Text('${date.length >= 10 ? date.substring(0, 10) : date} · outstanding ${CurrencyUtils.format(b.outstandingAmount)}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          ])),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  Widget _vendorHeader(String name) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.store_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          TextButton(onPressed: _pickVendor, child: const Text('Change')),
        ]),
      );

  Widget _form(_TargetBill target) {
    final over = _r2(_total) > _r2(target.outstanding) + 0.01;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Target bill header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            const Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(target.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              Text('Outstanding ${CurrencyUtils.format(target.outstanding)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ])),
            if (_vendorId != null) TextButton(onPressed: () => setState(() => _target = null), child: const Text('Change')),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('CN No. *'),
              TextField(controller: _cnNumberCtrl, decoration: _dec('Vendor\'s number'), style: const TextStyle(fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: _dateField('Date *', _date, _pickDate)),
        ]),
        const SizedBox(height: 14),
        _label('Reason'),
        DropdownButtonFormField<String>(
          initialValue: _reason,
          decoration: _dec('Reason'),
          items: kVendorCreditNoteReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => _reason = v ?? kVendorCreditNoteReasons.first),
        ),
        const SizedBox(height: 18),

        // Amounts
        Row(children: [
          const Text('Amount', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Spacer(),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Inter-state (IGST)', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            Switch(
              value: _interState,
              onChanged: (v) => setState(() => _interState = v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(flex: 5, child: _miniField('Taxable (₹)', _taxableCtrl, numeric: true)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _miniField('GST %', _gstCtrl, numeric: true)),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _miniField('Round off', _roundOffCtrl, numeric: true, signed: true)),
        ]),
        const SizedBox(height: 14),
        _totalsCard(target, over),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_saving || over) ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(_saving ? 'Saving…' : 'Save credit note'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _totalsCard(_TargetBill target, bool over) {
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
        row('Taxable', _taxable),
        if (!_interState) ...[
          row('CGST', _cgst),
          row('SGST', _sgst),
        ] else
          row('IGST', _igst),
        if (_roundOff != 0) row('Round off', _roundOff),
        const Divider(height: 18),
        row('Total', _total, bold: true, color: over ? AppColors.danger : AppColors.primary),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Must not exceed outstanding ${CurrencyUtils.format(target.outstanding)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: over ? AppColors.danger : AppColors.textMuted),
          ),
        ),
      ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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

  Widget _miniField(String label, TextEditingController c, {bool numeric = false, bool signed = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 3),
        TextField(
          controller: c,
          keyboardType: numeric ? TextInputType.numberWithOptions(decimal: true, signed: signed) : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(signed ? r'[0-9.\-]' : r'[0-9.]'))] : null,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(AppDateUtils.formatDisplay(value), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Searchable vendor picker (matches the vendor-pay screen pattern).
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

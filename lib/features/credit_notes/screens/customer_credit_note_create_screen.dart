import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/credit_note_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/credit_note_providers.dart';

/// Issue a customer credit note. Practical mobile shape (lump-sum first): pick a
/// customer, optionally target one of their open invoices to prefill amounts, then a
/// Taxable + GST% editor with an inter-state (IGST) toggle, round off and live total.
/// Mirrors the web create UI's required fields; the editable line-items grid is omitted.
class CustomerCreditNoteCreateScreen extends ConsumerStatefulWidget {
  const CustomerCreditNoteCreateScreen({super.key});
  @override
  ConsumerState<CustomerCreditNoteCreateScreen> createState() => _CustomerCreditNoteCreateScreenState();
}

class _CustomerCreditNoteCreateScreenState extends ConsumerState<CustomerCreditNoteCreateScreen> {
  final _extNumCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _taxableCtrl = TextEditingController();
  final _gstCtrl = TextEditingController(text: '18');
  final _roundOffCtrl = TextEditingController();

  Customer? _customer;
  List<Invoice> _openInvoices = const [];
  bool _loadingInvoices = false;
  int? _invoiceId;
  String? _sourceInvoiceNo;
  int _prefillItemCount = 0;
  bool _interState = false;
  DateTime _date = DateTime.now();
  bool _saving = false;

  late final ApiClient _client;

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  }

  @override
  void dispose() {
    _extNumCtrl.dispose();
    _reasonCtrl.dispose();
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

  Future<void> _pickCustomer() async {
    final chosen = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CustomerPicker(repo: CustomerRepository(_client)),
    );
    if (chosen != null) {
      setState(() {
        _customer = chosen;
        _invoiceId = null;
        _sourceInvoiceNo = null;
        _prefillItemCount = 0;
        _openInvoices = const [];
      });
      _loadOpenInvoices();
    }
  }

  Future<void> _loadOpenInvoices() async {
    final cust = _customer;
    if (cust == null) return;
    setState(() => _loadingInvoices = true);
    try {
      final list = await ref.read(creditNoteRepositoryProvider).getCustomerOpenInvoices(int.parse(cust.id));
      if (mounted) setState(() => _openInvoices = list);
    } catch (_) {
      // Non-fatal — the invoice picker just stays empty.
    } finally {
      if (mounted) setState(() => _loadingInvoices = false);
    }
  }

  Future<void> _pickInvoice() async {
    if (_customer == null) {
      _snack('Pick a customer first', error: true);
      return;
    }
    final chosen = await showModalBottomSheet<Invoice>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _InvoicePicker(invoices: _openInvoices, loading: _loadingInvoices),
    );
    if (chosen != null) await _applySuggestion(chosen);
  }

  Future<void> _applySuggestion(Invoice inv) async {
    try {
      final s = await ref.read(creditNoteRepositoryProvider).suggestFromInvoice(int.parse(inv.id));
      if (!mounted) return;
      setState(() {
        _invoiceId = int.tryParse(inv.id);
        _sourceInvoiceNo = inv.invoiceNumber;
        _interState = s.isInterState;
        _taxableCtrl.text = s.taxableAmount > 0 ? _r2(s.taxableAmount).toString() : '';
        if (s.gstPercent > 0) _gstCtrl.text = s.gstPercent.toString();
        _roundOffCtrl.text = s.roundOff != 0 ? _r2(s.roundOff).toString() : '';
        _prefillItemCount = s.items.length;
      });
    } catch (e) {
      _snack('Could not prefill from invoice: $e', error: true);
    }
  }

  void _clearInvoice() => setState(() {
        _invoiceId = null;
        _sourceInvoiceNo = null;
        _prefillItemCount = 0;
      });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_customer == null) {
      _snack('Pick a customer', error: true);
      return;
    }
    if (_total <= 0) {
      _snack('Enter a taxable amount so the total is greater than 0', error: true);
      return;
    }
    final body = <String, dynamic>{
      'creditNoteDate': _apiDate(_date),
      'customerId': int.parse(_customer!.id),
      if (_invoiceId != null) 'invoiceId': _invoiceId,
      if (_extNumCtrl.text.trim().isNotEmpty) 'externalNumber': _extNumCtrl.text.trim(),
      if (_reasonCtrl.text.trim().isNotEmpty) 'reason': _reasonCtrl.text.trim(),
      'taxableAmount': _r2(_taxable),
      'cgstAmount': _r2(_cgst),
      'sgstAmount': _r2(_sgst),
      'igstAmount': _r2(_igst),
      'roundOff': _r2(_roundOff),
      'totalAmount': _r2(_total),
    };
    await _create(body, override: false);
  }

  /// Posts the note. On a 409 `{ needsOverride, warnings }` soft-block, shows the
  /// warnings and offers "Apply anyway" which re-posts the identical body with override.
  Future<void> _create(Map<String, dynamic> body, {required bool override}) async {
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final cn = await ref.read(creditNoteRepositoryProvider).createCustomerCreditNote(body, override: override);
      if (!mounted) return;
      _snack('Credit note ${cn.creditNoteNumber.isEmpty ? 'issued' : cn.creditNoteNumber} issued');
      context.pop();
    } on AppException catch (e) {
      final data = e.data;
      if (e.statusCode == 409 && data is Map && data['needsOverride'] == true) {
        if (mounted) setState(() => _saving = false);
        final warnings = (data['warnings'] as List?)?.map((w) => w.toString()).toList() ?? const <String>[];
        final apply = await _confirmOverride(warnings);
        if (apply == true) {
          await _create(body, override: true);
        }
        return;
      }
      _snack(e.toString(), error: true);
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmOverride(List<String> warnings) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm credit note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The server flagged some warnings:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              ...warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text(w, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary))),
                    ]),
                  )),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply anyway')),
          ],
        ),
      );

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Credit Note')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('Customer *'),
          InkWell(
            onTap: _pickCustomer,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(_customer?.name ?? 'Select a customer', style: TextStyle(fontSize: 13, color: _customer != null ? AppColors.textPrimary : AppColors.textMuted))),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          _label('Against invoice (optional)'),
          InkWell(
            onTap: _customer == null ? null : _pickInvoice,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: _customer == null ? AppColors.background : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.description_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _invoiceId != null
                        ? 'Invoice ${_sourceInvoiceNo ?? _invoiceId}'
                        : _customer == null
                            ? 'Pick a customer first'
                            : _loadingInvoices
                                ? 'Loading open invoices…'
                                : _openInvoices.isEmpty
                                    ? 'No open invoices — leave blank for a standalone note'
                                    : 'Prefill from an open invoice',
                    style: TextStyle(fontSize: 13, color: _invoiceId != null ? AppColors.textPrimary : AppColors.textMuted),
                  ),
                ),
                if (_invoiceId != null)
                  InkWell(onTap: _clearInvoice, child: const Icon(Icons.close, size: 16, color: AppColors.textMuted))
                else
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
              ]),
            ),
          ),
          if (_prefillItemCount > 0) ...[
            const SizedBox(height: 6),
            Text('Prefilled from $_prefillItemCount invoice line${_prefillItemCount == 1 ? '' : 's'} — adjust the totals below if needed.',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _dateField('Date *', _date, _pickDate)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('External No.'),
                TextField(controller: _extNumCtrl, decoration: _dec('Optional'), style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('Credit Note No. is auto-assigned (CN-…) on save.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          _label('Reason'),
          TextField(controller: _reasonCtrl, decoration: _dec(CustomerCreditNoteStatus.reasonHint), style: const TextStyle(fontSize: 13)),
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
          _totalsCard(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Issuing…' : 'Issue credit note'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _totalsCard() {
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
        row('Total', _total, bold: true, color: AppColors.primary),
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

/// Searchable customer picker (same pattern as the quotation screen).
class _CustomerPicker extends StatefulWidget {
  final CustomerRepository repo;
  const _CustomerPicker({required this.repo});
  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  List<Customer> _items = [];
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
      final items = await widget.repo.getCustomers(search: q.isEmpty ? null : q);
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
            const Text('Select customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(controller: _ctrl, decoration: const InputDecoration(labelText: 'Search', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: _search),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(_items[i].name),
                        subtitle: _items[i].phone != null ? Text(_items[i].phone!) : null,
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

/// Bottom sheet listing the selected customer's open invoices (balance > 0).
class _InvoicePicker extends StatelessWidget {
  final List<Invoice> invoices;
  final bool loading;
  const _InvoicePicker({required this.invoices, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('Select invoice', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Only invoices with an outstanding balance are shown.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : invoices.isEmpty
                    ? const Center(child: Text('No open invoices for this customer.', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.separated(
                        itemCount: invoices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final inv = invoices[i];
                          return ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(inv.invoiceNumber),
                            subtitle: Text('Total ${CurrencyUtils.format(inv.totalAmount)} · Due ${CurrencyUtils.format(inv.outstandingAmount ?? 0)}',
                                style: const TextStyle(fontSize: 11.5)),
                            onTap: () => Navigator.pop(context, inv),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

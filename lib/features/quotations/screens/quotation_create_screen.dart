import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/quotation_providers.dart';

/// One editable quotation line — description, qty, rate, single GST% (matches the
/// web quotation editor). Amounts are computed client-side for preview only; the
/// server recomputes on save.
class _QuoteLine {
  final descCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final rateCtrl = TextEditingController();
  final gstCtrl = TextEditingController(text: '18');

  double get _qty => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get _rate => double.tryParse(rateCtrl.text.trim()) ?? 0;
  double get _gst => double.tryParse(gstCtrl.text.trim()) ?? 0;

  double get subtotal => _qty * _rate;
  double get tax => subtotal * _gst / 100;
  double get total => subtotal + tax;

  Map<String, dynamic> toPayload() => {
        'description': descCtrl.text.trim(),
        'quantity': _qty,
        'rate': _rate,
        'taxPercent': _gst,
      };

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
    gstCtrl.dispose();
  }
}

class QuotationCreateScreen extends ConsumerStatefulWidget {
  const QuotationCreateScreen({super.key});
  @override
  ConsumerState<QuotationCreateScreen> createState() => _QuotationCreateScreenState();
}

class _QuotationCreateScreenState extends ConsumerState<QuotationCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();
  final List<_QuoteLine> _lines = [_QuoteLine()];
  Customer? _customer;
  DateTime? _validUntil;
  bool _saving = false;

  late final ApiClient _client;

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  }

  @override
  void dispose() {
    _contactCtrl.dispose();
    _termsCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold<double>(0, (a, l) => a + l.subtotal);
  double get _tax => _lines.fold<double>(0, (a, l) => a + l.tax);
  double get _total => _lines.fold<double>(0, (a, l) => a + l.total);

  String _apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickCustomer() async {
    final chosen = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CustomerPicker(repo: CustomerRepository(_client)),
    );
    if (chosen != null) setState(() => _customer = chosen);
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 15)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _submit() async {
    if (_customer == null && _contactCtrl.text.trim().isEmpty) {
      _snack('Pick a customer or enter a contact name', error: true);
      return;
    }
    final validLines = _lines.where((l) => l.descCtrl.text.trim().isNotEmpty && l._qty > 0).toList();
    if (validLines.isEmpty) {
      _snack('Add at least one line with a description and quantity', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final q = await ref.read(quotationRepositoryProvider).createQuotation({
        if (_customer != null) 'customerId': int.parse(_customer!.id),
        if (_customer == null && _contactCtrl.text.trim().isNotEmpty) 'contactName': _contactCtrl.text.trim(),
        if (_validUntil != null) 'validUntil': _apiDate(_validUntil!),
        if (_termsCtrl.text.trim().isNotEmpty) 'terms': _termsCtrl.text.trim(),
        'lines': validLines.map((l) => l.toPayload()).toList(),
      });
      if (!mounted) return;
      _snack('Quotation ${q.quoteNumber} created');
      context.pushReplacement('/quotations/${q.id}');
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
      appBar: AppBar(title: const Text('New Quotation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _label('Customer'),
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
                  if (_customer != null)
                    InkWell(onTap: () => setState(() => _customer = null), child: const Icon(Icons.close, size: 16, color: AppColors.textMuted))
                  else
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            _label('Or contact name'),
            TextFormField(
              controller: _contactCtrl,
              enabled: _customer == null,
              decoration: _dec(_customer == null ? 'If there is no customer record yet' : 'Using selected customer'),
            ),
            const SizedBox(height: 14),
            _dateField('Valid until', _validUntil, _pickValidUntil),
            const SizedBox(height: 20),
            Row(children: [
              const Text('Line Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Spacer(),
              Text('${_lines.length} line${_lines.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 10),
            ...List.generate(_lines.length, (i) => _lineCard(i)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => setState(() => _lines.add(_QuoteLine())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add line'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
            ),
            const SizedBox(height: 16),
            _totalsCard(),
            const SizedBox(height: 14),
            _label('Terms / notes'),
            TextFormField(controller: _termsCtrl, maxLines: 3, decoration: _dec('Payment terms, delivery, validity…')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Create Quotation'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(int i) {
    final l = _lines[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22, height: 22, alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
            child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Item', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
          if (_lines.length > 1)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
              onPressed: () => setState(() => _lines.removeAt(i).dispose()),
            ),
        ]),
        const SizedBox(height: 8),
        TextFormField(controller: l.descCtrl, decoration: _dec('Description *'), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(flex: 3, child: _miniField('Qty', l.qtyCtrl, numeric: true)),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _miniField('Rate', l.rateCtrl, numeric: true)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _miniField('GST %', l.gstCtrl, numeric: true)),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Line ${CurrencyUtils.format(l.total)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ),
      ]),
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
        row('Subtotal', _subtotal),
        if (_tax > 0) row('GST', _tax),
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

  Widget _miniField(String label, TextEditingController c, {bool numeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 3),
        TextFormField(
          controller: c,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
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

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
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
              Text(value != null ? AppDateUtils.formatDisplay(value) : 'Select',
                  style: TextStyle(fontSize: 13, color: value != null ? AppColors.textPrimary : AppColors.textMuted)),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Searchable customer picker (same pattern as the service intake screen).
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

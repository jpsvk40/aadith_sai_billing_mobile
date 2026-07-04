import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Add an office expense — FULL parity with the web form: date, category (+ add new),
/// amount, description, paid by, payment mode, receipt note/collected, optional
/// GST-invoice (ITC) details and link to an open advance float.
class ExpenseEntryScreen extends ConsumerStatefulWidget {
  const ExpenseEntryScreen({super.key});
  @override
  ConsumerState<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends ConsumerState<ExpenseEntryScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _paidBy = TextEditingController();
  final _receiptNote = TextEditingController();
  final _newCategory = TextEditingController();
  // GST invoice (ITC)
  final _cgst = TextEditingController();
  final _sgst = TextEditingController();
  final _igst = TextEditingController();
  final _supplierGstin = TextEditingController();
  final _hsn = TextEditingController();

  List<String> _categories = const [];
  List<Map<String, dynamic>> _openFloats = const [];
  String? _category;
  bool _addingCategory = false;
  String _mode = 'Cash';
  DateTime _date = DateTime.now();
  bool _hasReceipt = false;
  bool _hasGstInvoice = false;
  int? _advanceFloatId;
  bool _saving = false;

  String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLookups());
  }

  @override
  void dispose() {
    for (final c in [_amount, _description, _paidBy, _receiptNote, _newCategory, _cgst, _sgst, _igst, _supplierGstin, _hsn]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        _client.get(ApiConstants.officeExpenseCategories).catchError((_) => const []),
        _client.get(ApiConstants.advanceFloats, queryParams: {'status': 'Open'}).catchError((_) => const []),
      ]);
      final cats = (results[0] is List ? results[0] as List : const [])
          .map((e) => e is Map ? (e['name'] ?? e['category'] ?? '').toString() : e.toString())
          .where((s) => s.trim().isNotEmpty)
          .cast<String>()
          .toList();
      final floats = (results[1] is List ? results[1] as List : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      if (mounted) {
        setState(() {
          _categories = cats;
          _category = cats.isNotEmpty ? cats.first : null;
          _addingCategory = cats.isEmpty;
          _openFloats = floats;
        });
      }
    } catch (_) {/* lookups are best-effort */}
  }

  double _n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    final amt = _n(_amount);
    final category = _addingCategory ? _newCategory.text.trim() : (_category ?? '');
    if (amt <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.'))); return; }
    if (category.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick or type a category.'))); return; }
    setState(() => _saving = true);
    try {
      await _client.post(ApiConstants.officeExpenses, data: {
        'expenseDate': _d(_date),
        'amount': amt,
        'category': category,
        'description': _description.text.trim(),
        'paidBy': _paidBy.text.trim(),
        'paymentMode': _mode,
        'receiptNote': _receiptNote.text.trim(),
        'hasReceipt': _hasReceipt,
        if (_advanceFloatId != null) 'advanceFloatId': _advanceFloatId,
        if (_hasGstInvoice) ...{
          'cgstAmount': _n(_cgst),
          'sgstAmount': _n(_sgst),
          'igstAmount': _n(_igst),
          'supplierGstin': _supplierGstin.text.trim(),
          'hsnSacCode': _hsn.text.trim(),
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense saved.')));
      context.pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add Expense')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ ', border: OutlineInputBorder(), isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(_date.year - 2), lastDate: DateTime.now());
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date *', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)),
                child: Text(_d(_date), style: const TextStyle(fontSize: 14.5)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        // Category (+ add new — mirrors web's "+ Add new category")
        if (!_addingCategory) ...[
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder(), isDense: true),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _addingCategory = true),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add new category', style: TextStyle(fontSize: 12)),
            ),
          ),
        ] else ...[
          TextField(controller: _newCategory, decoration: const InputDecoration(labelText: 'New category *', border: OutlineInputBorder(), isDense: true)),
          if (_categories.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _addingCategory = false),
                child: const Text('Pick existing instead', style: TextStyle(fontSize: 12)),
              ),
            ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 8),
        TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description — what was it for?', border: OutlineInputBorder(), alignLabelWithHint: true, isDense: true)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: TextField(controller: _paidBy, decoration: const InputDecoration(labelText: 'Paid by', border: OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _mode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Payment mode', border: OutlineInputBorder(), isDense: true),
              items: const ['Cash', 'Bank', 'UPI', 'Card', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _mode = v ?? 'Cash'),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(controller: _receiptNote, decoration: const InputDecoration(labelText: 'Receipt / note — receipt no, bill no…', border: OutlineInputBorder(), isDense: true)),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Receipt collected', style: TextStyle(fontSize: 13.5)),
          value: _hasReceipt,
          onChanged: (v) => setState(() => _hasReceipt = v ?? false),
        ),
        // Advance float link (petty cash)
        if (_openFloats.isNotEmpty) ...[
          DropdownButtonFormField<int?>(
            initialValue: _advanceFloatId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Pay from advance float (optional)', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('— none —')),
              ..._openFloats.map((f) => DropdownMenuItem<int?>(
                    value: f['id'] as int?,
                    child: Text('${f['title']} · bal ₹${(f['balance'] ?? 0).toString()}', overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() => _advanceFloatId = v),
          ),
          const SizedBox(height: 6),
        ],
        // GST invoice (ITC) — collapsible like the web checkbox
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('This expense has a GST invoice (for ITC)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
          value: _hasGstInvoice,
          onChanged: (v) => setState(() => _hasGstInvoice = v ?? false),
        ),
        if (_hasGstInvoice) ...[
          Row(children: [
            Expanded(child: TextField(controller: _cgst, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'CGST ₹', border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _sgst, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'SGST ₹', border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _igst, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'IGST ₹', border: OutlineInputBorder(), isDense: true))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(flex: 3, child: TextField(controller: _supplierGstin, decoration: const InputDecoration(labelText: 'Supplier GSTIN', border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: TextField(controller: _hsn, decoration: const InputDecoration(labelText: 'HSN/SAC', border: OutlineInputBorder(), isDense: true))),
          ]),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save expense')),
        const SizedBox(height: 24),
      ]),
    );
  }
}

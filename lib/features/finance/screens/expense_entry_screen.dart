import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Add an office expense (POST /api/office-expenses). Pops `true` on success so the list refreshes.
class ExpenseEntryScreen extends ConsumerStatefulWidget {
  const ExpenseEntryScreen({super.key});
  @override
  ConsumerState<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends ConsumerState<ExpenseEntryScreen> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  List<String> _categories = const [];
  String? _category;
  String _mode = 'Cash';
  DateTime _date = DateTime.now();
  bool _saving = false;

  String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());

  Future<void> _loadCategories() async {
    try {
      final data = await _client.get(ApiConstants.officeExpenseCategories);
      dynamic list = data is Map ? (data['data'] ?? data['categories'] ?? data.values.firstWhere((v) => v is List, orElse: () => const [])) : data;
      final cats = (list is List ? list : const [])
          .map((e) => e is Map ? (e['name'] ?? e['category'] ?? e['label'] ?? '').toString() : e.toString())
          .where((s) => s.trim().isNotEmpty)
          .cast<String>()
          .toList();
      if (mounted) setState(() { _categories = cats; _category = cats.isNotEmpty ? cats.first : null; });
    } catch (_) {/* categories are optional — free-text still works */}
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.'))); return; }
    setState(() => _saving = true);
    try {
      await _client.post(ApiConstants.officeExpenses, data: {
        'expenseDate': _d(_date),
        'amount': amt,
        'category': _category ?? 'General',
        'paymentMode': _mode,
        'description': _notes.text.trim(),
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
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ ', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(_date.year - 2),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _date = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date *', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
            child: Text(_d(_date), style: const TextStyle(fontSize: 15)),
          ),
        ),
        const SizedBox(height: 14),
        if (_categories.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
        if (_categories.isNotEmpty) const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _mode,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Payment mode', border: OutlineInputBorder()),
          items: const ['Cash', 'Bank', 'UPI', 'Card', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _mode = v ?? 'Cash'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder(), alignLabelWithHint: true),
        ),
        const SizedBox(height: 22),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save expense')),
      ]),
    );
  }
}

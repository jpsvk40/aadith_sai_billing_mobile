import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/erp_providers.dart';

const _kProjectStatuses = ['ENQUIRY', 'QUOTED', 'WON', 'LOST', 'ON_HOLD'];

/// Create / edit a project (ERP Project & Contract) — mirrors the web project form.
/// `status` and `contractValue` are manager-only server-side and only shown on edit.
class ProjectFormScreen extends ConsumerStatefulWidget {
  final int? editId;
  const ProjectFormScreen({super.key, this.editId});
  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _siteAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _contractValueCtrl = TextEditingController();
  int? _customerId;
  String? _customerName;
  String? _status;
  DateTime? _enquiryDate;
  DateTime? _expectedStartDate;

  bool _loading = false;
  bool _saving = false;
  late final ApiClient _client;

  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    if (_isEdit) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _enquiryDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _siteAddressCtrl.dispose();
    _notesCtrl.dispose();
    _contractValueCtrl.dispose();
    super.dispose();
  }

  String _apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String? _str(TextEditingController c) { final t = c.text.trim(); return t.isEmpty ? null : t; }
  num? _num(TextEditingController c) { final t = c.text.trim(); return t.isEmpty ? null : num.tryParse(t); }
  String _pretty(String s) => s.replaceAll('_', ' ');

  Future<void> _load() async {
    try {
      final p = await ref.read(erpRepositoryProvider).getProject(widget.editId!);
      String s(dynamic v) => (v ?? '').toString();
      _nameCtrl.text = s(p['projectName']);
      _cityCtrl.text = s(p['city']);
      _siteAddressCtrl.text = s(p['siteAddress']);
      _notesCtrl.text = s(p['notes']);
      _contractValueCtrl.text = p['contractValue'] != null ? s(p['contractValue']) : '';
      _status = _kProjectStatuses.contains(p['status']) ? s(p['status']) : null;
      _customerId = int.tryParse(s(p['customerId']));
      _customerName = p['customer'] is Map ? s((p['customer'] as Map)['customerName'] ?? (p['customer'] as Map)['name']) : s(p['customerName']);
      _enquiryDate = DateTime.tryParse(s(p['enquiryDate']));
      _expectedStartDate = DateTime.tryParse(s(p['expectedStartDate']));
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString(), error: true);
      }
    }
  }

  Future<void> _pickCustomer() async {
    final chosen = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CustomerPicker(repo: CustomerRepository(_client)),
    );
    if (chosen != null) {
      setState(() {
        _customerId = int.tryParse(chosen.id);
        _customerName = chosen.name;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _snack('Project name is required', error: true); return; }
    if (_customerId == null) { _snack('Pick a customer', error: true); return; }
    final body = <String, dynamic>{
      'projectName': name,
      'customerId': _customerId,
    };
    void put(String k, dynamic v) { if (v != null) body[k] = v; }
    put('city', _str(_cityCtrl));
    put('siteAddress', _str(_siteAddressCtrl));
    put('notes', _str(_notesCtrl));
    put('enquiryDate', _enquiryDate != null ? _apiDate(_enquiryDate!) : null);
    put('expectedStartDate', _expectedStartDate != null ? _apiDate(_expectedStartDate!) : null);
    // status + contractValue are manager-only and only editable after creation.
    if (_isEdit) {
      put('status', _status);
      put('contractValue', _num(_contractValueCtrl));
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(erpRepositoryProvider);
      if (_isEdit) {
        await repo.updateProject(widget.editId!, body);
      } else {
        await repo.createProject(body);
      }
      if (!mounted) return;
      _snack('Project "$name" ${_isEdit ? 'updated' : 'created'}');
      context.pop(true);
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
    final hasCustomer = (_customerName ?? '').isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Project' : 'New Project')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('Project Details'),
                  _field('Project name', _nameCtrl, required: true),
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
                        Expanded(child: Text(hasCustomer ? _customerName! : 'Select a customer', style: TextStyle(fontSize: 13, color: hasCustomer ? AppColors.textPrimary : AppColors.textMuted))),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isEdit)
                    _dropdown('Status', _status, _kProjectStatuses, (v) => setState(() => _status = v), hint: 'Select status'),
                  if (_isEdit)
                    _field('Contract value', _contractValueCtrl, hint: '0.00', numeric: true),
                  _field('City', _cityCtrl),
                  _field('Site address', _siteAddressCtrl, maxLines: 3),

                  _sectionTitle('Timeline & Notes'),
                  _dateField('Enquiry date', _enquiryDate, () async {
                    final picked = await showDatePicker(context: context, initialDate: _enquiryDate ?? DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _enquiryDate = picked);
                  }, onClear: _enquiryDate == null ? null : () => setState(() => _enquiryDate = null)),
                  const SizedBox(height: 14),
                  _dateField('Expected start date', _expectedStartDate, () async {
                    final picked = await showDatePicker(context: context, initialDate: _expectedStartDate ?? DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _expectedStartDate = picked);
                  }, onClear: _expectedStartDate == null ? null : () => setState(() => _expectedStartDate = null)),
                  const SizedBox(height: 14),
                  _field('Notes', _notesCtrl, maxLines: 3),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving…' : (_isEdit ? 'Save Changes' : 'Create Project')),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      );

  Widget _field(String label, TextEditingController c, {String? hint, bool numeric = false, int maxLines = 1, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(required ? '$label *' : label),
        TextFormField(
          controller: c,
          maxLines: maxLines,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
          style: const TextStyle(fontSize: 13),
          decoration: _dec(hint ?? label),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _dropdown(String label, String? value, List<String> options, ValueChanged<String?> onChanged, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: _dec(hint ?? 'Select'),
          hint: Text(hint ?? 'Select', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(_pretty(o), style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap, {VoidCallback? onClear}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(value != null ? AppDateUtils.formatDisplay(value) : 'Select', style: TextStyle(fontSize: 13, color: value != null ? AppColors.textPrimary : AppColors.textMuted))),
              if (value != null && onClear != null) InkWell(onTap: onClear, child: const Icon(Icons.close, size: 16, color: AppColors.textMuted)),
            ]),
          ),
        ),
      ],
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
}

/// Searchable customer picker (same pattern as the quotation create screen).
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/erp_list_models.dart';
import '../../../data/models/vendor_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/erp_repository.dart';
import '../../../data/repositories/vendor_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/erp_providers.dart';

const _kCategories = ['FABRICATION', 'CRANE', 'HOIST', 'GENERATOR', 'COMPRESSOR', 'VEHICLE', 'FORKLIFT', 'WELDING', 'POWER_TOOL', 'SCAFFOLDING', 'OTHER'];
const _kStatuses = ['ACTIVE', 'UNDER_MAINTENANCE', 'IDLE', 'HIRED_OUT', 'SCRAPPED'];
const _kOwnership = ['OWNED', 'HIRED_IN'];
const _kDepMethods = ['WDV', 'SLM'];

/// Create / edit a machine (P&M asset register) — mirrors the web machinery form.
/// Operators are blocked server-side (403), so the form is hidden for them.
class MachineFormScreen extends ConsumerStatefulWidget {
  final int? editId;
  const MachineFormScreen({super.key, this.editId});
  @override
  ConsumerState<MachineFormScreen> createState() => _MachineFormScreenState();
}

class _MachineFormScreenState extends ConsumerState<MachineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // Identity
  final _nameCtrl = TextEditingController();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _chassisCtrl = TextEditingController();
  final _engineCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  String? _category;
  // Ownership & purchase
  String? _ownership;
  int? _ownerVendorId;
  String? _ownerVendorName;
  int? _supplierVendorId;
  String? _supplierVendorName;
  DateTime? _purchaseDate;
  final _purchaseCostCtrl = TextEditingController();
  // Depreciation
  String? _depMethod;
  final _depRateCtrl = TextEditingController();
  final _usefulLifeCtrl = TextEditingController();
  final _salvageCtrl = TextEditingController();
  final _assetBlockCtrl = TextEditingController();
  // Operations
  final _meterTypeCtrl = TextEditingController(text: 'HOURS');
  final _currentMeterCtrl = TextEditingController();
  String? _status;
  int? _projectId;
  String? _projectName;
  final _locationCtrl = TextEditingController();
  final _operatorNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

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
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _makeCtrl, _modelCtrl, _serialCtrl, _regCtrl, _chassisCtrl, _engineCtrl, _capacityCtrl,
      _purchaseCostCtrl, _depRateCtrl, _usefulLifeCtrl, _salvageCtrl, _assetBlockCtrl,
      _meterTypeCtrl, _currentMeterCtrl, _locationCtrl, _operatorNameCtrl, _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String? _str(TextEditingController c) { final t = c.text.trim(); return t.isEmpty ? null : t; }
  num? _num(TextEditingController c) { final t = c.text.trim(); return t.isEmpty ? null : num.tryParse(t); }
  int? _int(TextEditingController c) { final t = c.text.trim(); return t.isEmpty ? null : int.tryParse(t); }
  String _pretty(String s) => s.replaceAll('_', ' ');

  Future<void> _load() async {
    try {
      final m = await ref.read(erpRepositoryProvider).getMachine(widget.editId!);
      String s(dynamic v) => (v ?? '').toString();
      _nameCtrl.text = s(m['name']);
      _makeCtrl.text = s(m['make']);
      _modelCtrl.text = s(m['model']);
      _serialCtrl.text = s(m['serialNo']);
      _regCtrl.text = s(m['registrationNo']);
      _chassisCtrl.text = s(m['chassisNo']);
      _engineCtrl.text = s(m['engineNo']);
      _capacityCtrl.text = s(m['capacity']);
      _purchaseCostCtrl.text = m['purchaseCost'] != null ? s(m['purchaseCost']) : '';
      _depRateCtrl.text = m['depreciationRate'] != null ? s(m['depreciationRate']) : '';
      _usefulLifeCtrl.text = m['usefulLifeYears'] != null ? s(m['usefulLifeYears']) : '';
      _salvageCtrl.text = m['salvageValue'] != null ? s(m['salvageValue']) : '';
      _assetBlockCtrl.text = s(m['assetBlock']);
      if (s(m['meterType']).isNotEmpty) _meterTypeCtrl.text = s(m['meterType']);
      _currentMeterCtrl.text = m['currentMeter'] != null ? s(m['currentMeter']) : '';
      _locationCtrl.text = s(m['currentLocation']);
      _operatorNameCtrl.text = s(m['operatorName']);
      _notesCtrl.text = s(m['notes']);
      _category = _kCategories.contains(m['category']) ? s(m['category']) : null;
      _ownership = _kOwnership.contains(m['ownership']) ? s(m['ownership']) : null;
      _depMethod = _kDepMethods.contains(m['depreciationMethod']) ? s(m['depreciationMethod']) : null;
      _status = _kStatuses.contains(m['status']) ? s(m['status']) : null;
      _ownerVendorId = int.tryParse(s(m['ownerVendorId']));
      _ownerVendorName = m['ownerVendor'] is Map ? s((m['ownerVendor'] as Map)['vendorName']) : null;
      _supplierVendorId = int.tryParse(s(m['supplierVendorId']));
      _supplierVendorName = m['supplierVendor'] is Map ? s((m['supplierVendor'] as Map)['vendorName']) : null;
      _projectId = int.tryParse(s(m['currentProjectId']));
      _projectName = m['currentProject'] is Map ? s((m['currentProject'] as Map)['projectName']) : s(m['projectName']);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString(), error: true);
      }
    }
  }

  Future<void> _pickVendor({required bool owner}) async {
    final chosen = await showModalBottomSheet<Vendor>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VendorPicker(repo: VendorRepository(_client)),
    );
    if (chosen != null) {
      setState(() {
        if (owner) {
          _ownerVendorId = int.tryParse(chosen.id);
          _ownerVendorName = chosen.vendorName;
        } else {
          _supplierVendorId = int.tryParse(chosen.id);
          _supplierVendorName = chosen.vendorName;
        }
      });
    }
  }

  Future<void> _pickProject() async {
    final chosen = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProjectPicker(repo: ref.read(erpRepositoryProvider)),
    );
    if (chosen != null) {
      setState(() {
        _projectId = chosen.id;
        _projectName = chosen.projectName;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _snack('Machine name is required', error: true); return; }
    final body = <String, dynamic>{'name': name};
    void put(String k, dynamic v) { if (v != null) body[k] = v; }
    put('category', _category);
    put('make', _str(_makeCtrl));
    put('model', _str(_modelCtrl));
    put('serialNo', _str(_serialCtrl));
    put('registrationNo', _str(_regCtrl));
    put('chassisNo', _str(_chassisCtrl));
    put('engineNo', _str(_engineCtrl));
    put('capacity', _str(_capacityCtrl));
    put('ownership', _ownership);
    put('ownerVendorId', _ownerVendorId);
    put('supplierVendorId', _supplierVendorId);
    put('purchaseDate', _purchaseDate != null ? _apiDate(_purchaseDate!) : null);
    put('purchaseCost', _num(_purchaseCostCtrl));
    put('depreciationMethod', _depMethod);
    put('depreciationRate', _num(_depRateCtrl));
    put('usefulLifeYears', _int(_usefulLifeCtrl));
    put('salvageValue', _num(_salvageCtrl));
    put('assetBlock', _str(_assetBlockCtrl));
    put('meterType', _str(_meterTypeCtrl));
    put('currentMeter', _num(_currentMeterCtrl));
    put('status', _status);
    put('currentProjectId', _projectId);
    put('currentLocation', _str(_locationCtrl));
    put('operatorName', _str(_operatorNameCtrl));
    put('notes', _str(_notesCtrl));

    setState(() => _saving = true);
    try {
      final repo = ref.read(erpRepositoryProvider);
      if (_isEdit) {
        await repo.updateMachine(widget.editId!, body);
      } else {
        await repo.createMachine(body);
      }
      if (!mounted) return;
      _snack('Machine "$name" ${_isEdit ? 'updated' : 'created'}');
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
    final user = ref.watch(authProvider).user;
    if (user?.isOperator == true) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Machine')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: 44, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text('Adding or editing machines isn\'t available for operators.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Machine' : 'New Machine')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('Identity'),
                  _field('Name', _nameCtrl, required: true),
                  _dropdown('Category', _category, _kCategories, (v) => setState(() => _category = v), hint: 'Select category'),
                  Row(children: [
                    Expanded(child: _field('Make', _makeCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Model', _modelCtrl)),
                  ]),
                  _field('Serial no', _serialCtrl),
                  _field('Registration no', _regCtrl),
                  Row(children: [
                    Expanded(child: _field('Chassis no', _chassisCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Engine no', _engineCtrl)),
                  ]),
                  _field('Capacity', _capacityCtrl, hint: 'e.g. 5 Ton, 50 kVA'),

                  _sectionTitle('Ownership & Purchase'),
                  _dropdown('Ownership', _ownership, _kOwnership, (v) => setState(() => _ownership = v), hint: 'Select ownership'),
                  _pickerField('Lessor (if hired)', _ownerVendorName, Icons.handshake_outlined, () => _pickVendor(owner: true), onClear: () => setState(() { _ownerVendorId = null; _ownerVendorName = null; })),
                  _pickerField('Supplier (if owned)', _supplierVendorName, Icons.store_outlined, () => _pickVendor(owner: false), onClear: () => setState(() { _supplierVendorId = null; _supplierVendorName = null; })),
                  _dateField('Purchase date', _purchaseDate, () async {
                    final picked = await showDatePicker(context: context, initialDate: _purchaseDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _purchaseDate = picked);
                  }, onClear: _purchaseDate == null ? null : () => setState(() => _purchaseDate = null)),
                  const SizedBox(height: 14),
                  _field('Purchase cost', _purchaseCostCtrl, hint: '0.00', numeric: true),

                  _sectionTitle('Depreciation'),
                  _dropdown('Depreciation method', _depMethod, _kDepMethods, (v) => setState(() => _depMethod = v), hint: 'Select method'),
                  Row(children: [
                    Expanded(child: _field('Rate %', _depRateCtrl, numeric: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Useful life (yrs)', _usefulLifeCtrl, integer: true)),
                  ]),
                  _field('Salvage value', _salvageCtrl, hint: '0.00', numeric: true),
                  _field('Asset block', _assetBlockCtrl),

                  _sectionTitle('Operations'),
                  Row(children: [
                    Expanded(child: _field('Meter type', _meterTypeCtrl, hint: 'HOURS / KM')),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Current meter', _currentMeterCtrl, numeric: true)),
                  ]),
                  _dropdown('Status', _status, _kStatuses, (v) => setState(() => _status = v), hint: 'Select status'),
                  _pickerField('Deployed at Project', _projectName, Icons.apartment_outlined, _pickProject, onClear: () => setState(() { _projectId = null; _projectName = null; })),
                  _field('Current location', _locationCtrl),
                  _field('Operator name', _operatorNameCtrl),
                  _field('Notes', _notesCtrl, maxLines: 3),

                  const SizedBox(height: 8),
                  _submitButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _submitButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check),
          label: Text(_saving ? 'Saving…' : (_isEdit ? 'Save Changes' : 'Create Machine')),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      );

  Widget _field(String label, TextEditingController c, {String? hint, bool numeric = false, bool integer = false, int maxLines = 1, bool required = false}) {
    final isNum = numeric || integer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(required ? '$label *' : label),
        TextFormField(
          controller: c,
          maxLines: maxLines,
          keyboardType: integer
              ? TextInputType.number
              : (numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
          inputFormatters: isNum
              ? [FilteringTextInputFormatter.allow(RegExp(integer ? r'[0-9]' : r'[0-9.]'))]
              : null,
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

  Widget _pickerField(String label, String? value, IconData icon, VoidCallback onTap, {VoidCallback? onClear}) {
    final has = (value ?? '').isNotEmpty;
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
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(has ? value! : 'Select', style: TextStyle(fontSize: 13, color: has ? AppColors.textPrimary : AppColors.textMuted))),
              if (has && onClear != null)
                InkWell(onTap: onClear, child: const Icon(Icons.close, size: 16, color: AppColors.textMuted))
              else
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ]),
          ),
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

/// Searchable vendor picker (same pattern as the vendor-pay screen).
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

/// Searchable project picker (client-side filtered — the list endpoint is small).
class _ProjectPicker extends StatefulWidget {
  final ErpRepository repo;
  const _ProjectPicker({required this.repo});
  @override
  State<_ProjectPicker> createState() => _ProjectPickerState();
}

class _ProjectPickerState extends State<_ProjectPicker> {
  List<Project> _all = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repo.getProjects();
      if (mounted) setState(() { _all = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
        ? _all
        : _all.where((p) => p.projectName.toLowerCase().contains(_q.toLowerCase()) || p.projectCode.toLowerCase().contains(_q.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('Select project', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(decoration: const InputDecoration(labelText: 'Search', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => _q = v)),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => ListTile(
                        leading: const Icon(Icons.apartment_outlined),
                        title: Text(filtered[i].projectName),
                        subtitle: filtered[i].projectCode.isNotEmpty ? Text(filtered[i].projectCode) : null,
                        onTap: () => Navigator.pop(context, filtered[i]),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

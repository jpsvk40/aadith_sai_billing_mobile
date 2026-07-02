import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/service_item_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/service_providers.dart';
import '../service_status.dart';

/// Admin intake: raise a new service ticket. Customer picker + problem + type/priority + optional
/// labour/tax (billing roles).
class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});
  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemCtrl = TextEditingController();
  final _labourCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '18');
  Customer? _customer;
  String _serviceType = 'PAID_REPAIR';
  String _priority = 'NORMAL';
  String _location = 'IN_SHOP';
  bool _saving = false;
  bool _triaging = false;
  ServiceTriage? _triage;

  static const _serviceTypes = ['PAID_REPAIR', 'IN_WARRANTY', 'OUT_OF_WARRANTY', 'AMC', 'INSTALLATION'];
  static const _priorities = ['LOW', 'NORMAL', 'HIGH', 'URGENT'];

  @override
  void dispose() {
    _problemCtrl.dispose();
    _labourCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final repo = CustomerRepository(ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout()));
    final chosen = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CustomerPicker(repo: repo),
    );
    if (chosen != null) setState(() => _customer = chosen);
  }

  Future<void> _submit() async {
    if (_customer == null) { _snack('Select a customer', error: true); return; }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final canBill = ref.read(authProvider).user?.canBill == true;
    try {
      final t = await ref.read(serviceRepositoryProvider).createTicket({
        'customerId': int.parse(_customer!.id),
        'reportedProblem': _problemCtrl.text.trim(),
        'serviceType': _serviceType,
        'priority': _priority,
        'location': _location,
        if (canBill && _labourCtrl.text.trim().isNotEmpty) 'labourCharge': double.tryParse(_labourCtrl.text.trim()) ?? 0,
        if (canBill && _taxCtrl.text.trim().isNotEmpty) 'taxPercent': double.tryParse(_taxCtrl.text.trim()) ?? 0,
      });
      ref.read(allTicketsProvider.notifier).load();
      if (!mounted) return;
      _snack('Ticket ${t.ticketNumber} created');
      context.go('/service/tickets/${t.id}');
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
    final canBill = ref.watch(authProvider).user?.canBill == true;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Service Ticket')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
              leading: const Icon(Icons.person_outline),
              title: Text(_customer?.name ?? 'Select customer *'),
              subtitle: _customer?.phone != null ? Text(_customer!.phone!) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickCustomer,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _problemCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reported problem *', border: OutlineInputBorder(), alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _triaging ? null : _runTriage,
                icon: _triaging
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_triaging ? 'Analysing…' : 'AI Assist'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            if (_triage != null) ...[
              const SizedBox(height: 10),
              _triageCard(_triage!),
            ],
            const SizedBox(height: 14),
            _dropdown('Service type', _serviceType, _serviceTypes, (v) => setState(() => _serviceType = v!), labelOf: ServiceStatus.serviceTypeLabel),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _dropdown('Priority', _priority, _priorities, (v) => setState(() => _priority = v!))),
              const SizedBox(width: 12),
              Expanded(child: _dropdown('Location', _location, const ['IN_SHOP', 'ONSITE'], (v) => setState(() => _location = v!), labelOf: (l) => l == 'ONSITE' ? 'On-site' : 'In-shop')),
            ]),
            if (canBill) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextFormField(controller: _labourCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Labour charge', prefixText: '₹ ', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _taxCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tax %', border: OutlineInputBorder()))),
              ]),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create ticket'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTriage() async {
    final problem = _problemCtrl.text.trim();
    if (problem.isEmpty) { _snack('Describe the problem first', error: true); return; }
    setState(() => _triaging = true);
    try {
      final t = await ref.read(serviceRepositoryProvider).aiTriage(
            reportedProblem: problem,
            modelName: _customer?.name, // best-effort context; device model unknown at intake
            underWarranty: _serviceType == 'IN_WARRANTY',
          );
      if (mounted) setState(() => _triage = t);
    } catch (e) {
      final msg = e.toString().toLowerCase().contains('not configured')
          ? 'AI Assist isn\'t configured on the server (missing OpenAI key).'
          : e.toString();
      _snack(msg, error: true);
    } finally {
      if (mounted) setState(() => _triaging = false);
    }
  }

  void _applyAll(ServiceTriage t) {
    setState(() {
      if (_priorities.contains(t.priority)) _priority = t.priority;
      if (t.estimatedLabour > 0) _labourCtrl.text = t.estimatedLabour.toString();
      if (t.cleanedProblem.isNotEmpty) _problemCtrl.text = t.cleanedProblem;
    });
    _snack('Applied AI suggestions');
  }

  Widget _triageCard(ServiceTriage t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDD6FE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          const Text('AI Suggestion', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
          const Spacer(),
          TextButton(
            onPressed: () => _applyAll(t),
            style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: const Text('Apply all'),
          ),
        ]),
        const SizedBox(height: 4),
        _line('Priority', ServiceStatus.label(t.priority)),
        if (t.faultCategory.isNotEmpty) _line('Fault', t.faultCategory),
        if (t.estimatedLabour > 0) _line('Est. labour', '₹${t.estimatedLabour}'),
        if (t.estimatedTurnaroundDays != null) _line('Turnaround', '${t.estimatedTurnaroundDays} day(s)'),
        if (t.probableCauses.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Probable causes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          ...t.probableCauses.map((c) => Text('•  $c', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
        ],
        if (t.suggestedParts.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Likely parts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: t.suggestedParts
              .map((p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFDDD6FE))),
                    child: Text(p, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6D28D9))),
                  ))
              .toList()),
        ],
        if (t.diagnosticChecklist.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Diagnostic checklist', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          ...t.diagnosticChecklist.map((c) => Text('☐  $c', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
        ],
        if (t.cleanedProblem.isNotEmpty && t.cleanedProblem != _problemCtrl.text.trim()) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _problemCtrl.text = t.cleanedProblem),
              icon: const Icon(Icons.notes, size: 16),
              label: const Text('Use tidied description'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
            ),
          ),
        ],
        const SizedBox(height: 4),
        const Text('AI suggestion — review before applying.', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 100, child: Text(k, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ]),
      );

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged, {String Function(String)? labelOf}) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(labelOf?.call(o) ?? o))).toList(),
      onChanged: onChanged,
    );
  }
}

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

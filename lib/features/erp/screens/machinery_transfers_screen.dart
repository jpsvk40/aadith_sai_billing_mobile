import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/erp_list_models.dart';
import '../../../data/models/machine_detail_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/erp_providers.dart';
import '../providers/machinery_providers.dart';
import 'erp_common.dart';

const _accent = Color(0xFF0891B2); // transfers/logistics cyan (matches the receive-queue tile)
const _accentDark = Color(0xFF0E7490);

/// Full Machine Transfers register (GET /machinery/transfers) — every transfer incl.
/// RECEIVED history, not just the pending receive-queue (MachineTransfersSection).
/// Status filter + create-transfer + one-tap receive, mirroring the web page.
class MachineryTransfersScreen extends ConsumerStatefulWidget {
  const MachineryTransfersScreen({super.key});
  @override
  ConsumerState<MachineryTransfersScreen> createState() => _MachineryTransfersScreenState();
}

class _MachineryTransfersScreenState extends ConsumerState<MachineryTransfersScreen> {
  static const _statuses = ['PENDING', 'IN_TRANSIT', 'RECEIVED'];
  String _filter = 'all';
  String _q = '';

  List<MachineTransferLite> _visible(List<MachineTransferLite> rows) {
    return rows.where((t) {
      if (_filter != 'all' && t.status != _filter) return false;
      if (_q.isEmpty) return true;
      final s = _q.toLowerCase();
      return t.transferCode.toLowerCase().contains(s) ||
          (t.machineName ?? '').toLowerCase().contains(s) ||
          (t.machineCode ?? '').toLowerCase().contains(s) ||
          (t.fromName ?? '').toLowerCase().contains(s) ||
          (t.toName ?? '').toLowerCase().contains(s);
    }).toList();
  }

  Future<void> _newTransfer() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _NewTransferSheet(),
    );
    if (saved == true) ref.invalidate(machineTransfersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isOperator = ref.watch(authProvider).user?.isOperator == true;
    final async = ref.watch(machineTransfersProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Machine Transfers')),
      floatingActionButton: isOperator
          ? null
          : FloatingActionButton.extended(
              onPressed: _newTransfer,
              backgroundColor: _accent,
              icon: const Icon(Icons.add),
              label: const Text('New Transfer'),
            ),
      body: async.when(
        loading: () => const LoadingIndicator(message: 'Loading transfers…'),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(machineTransfersProvider)),
        data: (rows) {
          final filtered = _visible(rows);
          final inTransit = rows.where((t) => t.status != 'RECEIVED').length;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(children: [
                ErpHero(gradient: const [_accent, _accentDark], icon: Icons.swap_horiz, stats: [
                  ('Transfers', '${rows.length}'),
                  ('In transit', '$inTransit'),
                  ('Received', '${rows.where((t) => t.status == 'RECEIVED').length}'),
                ]),
                const SizedBox(height: 12),
                ErpSearchField(hint: 'Search code, machine, site…', onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: 10),
                ErpFilterChips(
                  options: buildFixedStatusOptions(_statuses, rows.map((t) => t.status)),
                  selected: _filter,
                  accent: _accent,
                  onSelect: (v) => setState(() => _filter = v),
                ),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(machineTransfersProvider),
                child: filtered.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 40),
                        ErpEmpty(icon: Icons.swap_horiz, text: 'No transfers match.'),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _TransferCard(transfer: filtered[i]),
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _TransferCard extends ConsumerStatefulWidget {
  final MachineTransferLite transfer;
  const _TransferCard({required this.transfer});
  @override
  ConsumerState<_TransferCard> createState() => _TransferCardState();
}

class _TransferCardState extends ConsumerState<_TransferCard> {
  bool _busy = false;

  Future<void> _receive() async {
    setState(() => _busy = true);
    try {
      await ref.read(machineryRepositoryProvider).receiveTransfer(widget.transfer.id);
      ref.invalidate(machineTransfersProvider);
      ref.invalidate(machineryListProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.transfer.transferCode} received')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    final received = t.status == 'RECEIVED';
    final statusColor = ErpCard.statusColor(t.status);
    final machineTitle = [t.machineCode, t.machineName].where((e) => e != null && e.isNotEmpty).join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.local_shipping_outlined, size: 18, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(t.transferCode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _accentDark)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(t.status.replaceAll('_', ' '), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(machineTitle.isEmpty ? 'Machine' : machineTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _leg('From', t.fromName)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted)),
          Expanded(child: _leg('To', t.toName)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text(_fmtDate(t.transferDate), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          if (t.transportCost != null && t.transportCost! > 0) ...[
            const SizedBox(width: 12),
            const Icon(Icons.payments_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text('₹${_fmtNum(t.transportCost!)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
          if ((t.gatePassNo ?? '').isNotEmpty) ...[
            const SizedBox(width: 12),
            const Icon(Icons.confirmation_number_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Flexible(child: Text(t.gatePassNo!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
          ],
        ]),
        if (!received) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _busy ? null : _receive,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_busy)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Icons.check, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(_busy ? 'Receiving…' : 'Mark Received', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _leg(String label, String? value) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value == null || value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ]);

  static String _fmtNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }
}

/// New-transfer form (POST /machinery/transfers). Machine is required; the rest map
/// one-to-one to the web dispatch form (from location, to project/location, transport
/// cost, gate pass, vehicle, notes).
class _NewTransferSheet extends ConsumerStatefulWidget {
  const _NewTransferSheet();
  @override
  ConsumerState<_NewTransferSheet> createState() => _NewTransferSheetState();
}

class _NewTransferSheetState extends ConsumerState<_NewTransferSheet> {
  int? _machineId;
  int? _toProjectId;
  DateTime _date = DateTime.now();
  final _fromLocation = TextEditingController();
  final _toLocation = TextEditingController();
  final _transportCost = TextEditingController();
  final _gatePass = TextEditingController();
  final _vehicle = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_fromLocation, _toLocation, _transportCost, _gatePass, _vehicle, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_machineId == null) {
      setState(() => _error = 'Select the machine to transfer.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(machineryRepositoryProvider).createTransfer(
            machineId: _machineId!,
            transferDate: _date,
            fromLocation: _fromLocation.text.trim(),
            toProjectId: _toProjectId,
            toLocation: _toLocation.text.trim(),
            transportCost: double.tryParse(_transportCost.text.trim()),
            gatePassNo: _gatePass.text.trim(),
            vehicleUsed: _vehicle.text.trim(),
            notes: _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machineryListProvider).valueOrNull ?? const <Machine>[];
    final projects = ref.watch(projectsListProvider).valueOrNull ?? const <Project>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Align(alignment: Alignment.centerLeft, child: Text('New Transfer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              children: [
                _label('Machine *'),
                DropdownButtonFormField<int>(
                  initialValue: _machineId,
                  isExpanded: true,
                  decoration: _dec('Select machine'),
                  items: machines
                      .map((m) => DropdownMenuItem<int>(value: m.id, child: Text('${m.machineCode} — ${m.name}', overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => _machineId = v),
                ),
                const SizedBox(height: 14),
                _label('Transfer date'),
                _dateField(),
                const SizedBox(height: 14),
                _label('From (location)'),
                TextField(controller: _fromLocation, decoration: _dec('Current site / yard')),
                const SizedBox(height: 14),
                _label('To project'),
                DropdownButtonFormField<int>(
                  initialValue: _toProjectId,
                  isExpanded: true,
                  decoration: _dec('— none —'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('— none —')),
                    ...projects.map((p) => DropdownMenuItem<int>(value: p.id, child: Text('${p.projectCode} — ${p.projectName}', overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _toProjectId = v),
                ),
                const SizedBox(height: 14),
                _label('To (location)'),
                TextField(controller: _toLocation, decoration: _dec('Destination site / yard')),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Transport cost'),
                    TextField(controller: _transportCost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec('₹ 0')),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label('Gate pass no'),
                    TextField(controller: _gatePass, decoration: _dec('GP-…')),
                  ])),
                ]),
                const SizedBox(height: 14),
                _label('Vehicle used'),
                TextField(controller: _vehicle, decoration: _dec('Truck / trailer reg. no')),
                const SizedBox(height: 14),
                _label('Notes'),
                TextField(controller: _notes, maxLines: 2, decoration: _dec('Optional')),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save Transfer', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dateField() => InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 1));
          if (picked != null) setState(() => _date = picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('${_date.day}/${_date.month}/${_date.year}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textSecondary)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      );
}

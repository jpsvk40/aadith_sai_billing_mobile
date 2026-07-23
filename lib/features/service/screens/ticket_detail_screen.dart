import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/service_ticket_model.dart';
import '../../../data/models/service_item_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/service_providers.dart';
import '../service_status.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final int ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});
  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  bool _busy = false;
  ServiceTriage? _triage; // inline AI diagnosis (probable causes / parts / checklist)
  bool _triaging = false;

  void _refresh() {
    ref.invalidate(ticketDetailProvider(widget.ticketId));
    ref.invalidate(ticketAttachmentsProvider(widget.ticketId));
    // Keep the lists fresh too (status moves a ticket between filters).
    ref.read(myTicketsProvider.notifier).load();
    ref.read(allTicketsProvider.notifier).load();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success));
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _navigate(String query) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<T?> _run<T>(Future<T> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      final r = await action();
      _refresh();
      if (success != null) _snack(success);
      return r;
    } catch (e) {
      _snack(e.toString(), error: true);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketDetailProvider(widget.ticketId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/service/tickets'),
        ),
        title: Text(async.valueOrNull?.ticketNumber ?? 'Ticket'),
        actions: [
          if (async.valueOrNull != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                final t = async.value!;
                switch (v) {
                  case 'jobsheet': _showJobSheet(t); break;
                  case 'certificate': _showCertificate(t); break;
                  case 'share': _shareTracking(t); break;
                  case 'rework': _reworkSheet(t); break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'jobsheet', child: ListTile(dense: true, leading: Icon(Icons.description_outlined), title: Text('Job sheet'))),
                if (['READY', 'DELIVERED', 'CLOSED'].contains(async.value!.status))
                  const PopupMenuItem(value: 'certificate', child: ListTile(dense: true, leading: Icon(Icons.workspace_premium_outlined), title: Text('Service certificate'))),
                const PopupMenuItem(value: 'share', child: ListTile(dense: true, leading: Icon(Icons.share_outlined), title: Text('Share tracking link'))),
                if (['DELIVERED', 'CLOSED'].contains(async.value!.status))
                  const PopupMenuItem(value: 'rework', child: ListTile(dense: true, leading: Icon(Icons.replay, color: Color(0xFF7C3AED)), title: Text('Reopen for rework'))),
              ],
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(ticketDetailProvider(widget.ticketId))),
        data: (t) => _body(t),
      ),
    );
  }

  Widget _body(ServiceTicket t) {
    final user = ref.watch(authProvider).user;
    final canBill = user?.canBill == true;
    // The company-replacement legs are driven by the RMA card, not the plain status sheet.
    final nexts = ServiceStatus.plainNextStatuses(t.status);
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _statusHeader(t),
              const SizedBox(height: 12),
              _section('Customer & Device', [
                _kv('Customer', t.customerName),
                if (t.customer?.phone != null) _kv('Phone', t.customer!.phone!),
                if (t.serviceItem != null) ...[
                  _kv('Device', t.serviceItem!.label.isEmpty ? (t.serviceItem!.category ?? '—') : t.serviceItem!.label),
                  if (t.serviceItem!.serialNumber != null) _kv('Serial', t.serviceItem!.serialNumber!),
                  if (t.serviceItem!.warrantyEndDate != null)
                    _kv('Warranty till', AppDateUtils.formatDisplay(t.serviceItem!.warrantyEndDate)),
                ],
                _kv('Type', ServiceStatus.serviceTypeLabel(t.serviceType)),
                _kv('Location', t.location == 'ONSITE' ? 'On-site' : 'In-shop'),
                if ((t.customer?.phone ?? '').isNotEmpty || t.location == 'ONSITE' || t.customer?.id != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      if ((t.customer?.phone ?? '').isNotEmpty)
                        OutlinedButton.icon(onPressed: () => _call(t.customer!.phone!), icon: const Icon(Icons.call, size: 18), label: const Text('Call')),
                      if (t.location == 'ONSITE')
                        OutlinedButton.icon(onPressed: () => _navigate(t.customerName), icon: const Icon(Icons.directions, size: 18), label: const Text('Navigate')),
                      if (t.customer?.id != null)
                        OutlinedButton.icon(onPressed: () => context.push('/service/customers/${t.customer!.id}'), icon: const Icon(Icons.history, size: 18), label: const Text('History')),
                    ]),
                  ),
              ]),
              const SizedBox(height: 12),
              _section('Problem & Diagnosis', [
                _kv('Reported', t.reportedProblem),
                if ((t.intakeCondition ?? '').isNotEmpty) _kv('Intake condition', t.intakeCondition!),
                if (t.accessories.isNotEmpty) _kv('Accessories', t.accessories.join(', ')),
                if ((t.devicePassword ?? '').isNotEmpty) _kv('Device password', t.devicePassword!),
                if ((t.diagnosis ?? '').isNotEmpty) _kv('Diagnosis', t.diagnosis!),
                if ((t.resolution ?? '').isNotEmpty) _kv('Resolution', t.resolution!),
              ], trailing: TextButton.icon(
                onPressed: _busy ? null : () => _editDiagnosis(t),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Update'),
              )),
              const SizedBox(height: 12),
              _aiDiagnosisSection(t),
              if (canBill) ...[
                const SizedBox(height: 12),
                _adminSection(t),
              ] else if (t.estimateStatus != 'NONE') ...[
                // Technician view: the estimate decides whether they may proceed — show it read-only.
                const SizedBox(height: 12),
                _estimateInfoSection(t),
              ],
              const SizedBox(height: 12),
              _partsSection(t),
              const SizedBox(height: 12),
              _rmaSection(t),
              const SizedBox(height: 12),
              _photosSection(t),
              const SizedBox(height: 12),
              _chargesSection(t, canBill),
              const SizedBox(height: 12),
              _timeline(t),
            ],
          ),
        ),
        if (_busy) const Positioned.fill(child: ColoredBox(color: Color(0x33000000), child: Center(child: CircularProgressIndicator()))),
        _bottomBar(t, nexts, canBill),
      ],
    );
  }

  // ─── Header ───
  Widget _statusHeader(ServiceTicket t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.ticketNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 4),
                Text('Reported ${AppDateUtils.formatDisplay(t.reportedAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (t.promisedAt != null)
                  Text('Promised ${AppDateUtils.formatDisplay(t.promisedAt)}', style: TextStyle(fontSize: 12, color: t.slaBreached ? AppColors.danger : AppColors.textSecondary)),
                if (t.isRework && t.reworkOf != null || t.reworks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      if (t.isRework && t.reworkOf != null)
                        _reworkBadge('↺ Rework of ${t.reworkOf!.ticketNumber}', () => context.push('/service/tickets/${t.reworkOf!.id}')),
                      ...t.reworks.map((r) => _reworkBadge('Reworked → ${r.ticketNumber}', () => context.push('/service/tickets/${r.id}'))),
                    ]),
                  ),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ServiceStatusChip(status: t.status),
            if (t.slaBreached) const Padding(padding: EdgeInsets.only(top: 6), child: Text('SLA breached', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
        ],
      ),
    );
  }

  // ─── Admin: assignment + estimate ───
  Widget _adminSection(ServiceTicket t) {
    final hasEstimate = t.estimateStatus != 'NONE';
    return _section('Assignment & Estimate', [
      _kv('Technician', t.technician?.name ?? 'Unassigned'),
      if (hasEstimate) _kv('Estimate', '${t.estimateStatus}${t.estimateAmount != null ? ' · ${CurrencyUtils.format(t.estimateAmount)}' : ''}'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (t.isOpen)
          OutlinedButton.icon(onPressed: _busy ? null : () => _assign(t), icon: const Icon(Icons.person_add_alt, size: 18), label: Text(t.assignedTechnicianId == null ? 'Assign' : 'Reassign')),
        if (t.isOpen && t.isChargeable)
          OutlinedButton.icon(onPressed: _busy ? null : () => _raiseEstimate(t), icon: const Icon(Icons.request_quote_outlined, size: 18), label: Text(hasEstimate ? 'Revise estimate' : 'Raise estimate')),
        if (t.estimateStatus == 'PENDING')
          ElevatedButton.icon(onPressed: _busy ? null : () => _approveEstimate(t), icon: const Icon(Icons.check_circle_outline, size: 18), label: const Text('Approve estimate')),
      ]),
    ]);
  }

  Future<void> _assign(ServiceTicket t) async {
    final techs = await _run(() => ref.read(serviceRepositoryProvider).getTechnicians());
    if (techs == null || !mounted) return;
    if (techs.isEmpty) { _snack('No technicians available', error: true); return; }
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Assign technician', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ...techs.map((e) => ListTile(
                leading: const Icon(Icons.engineering_outlined),
                title: Text(e.fullName),
                subtitle: Text([e.employeeCode, e.designation].where((x) => (x ?? '').isNotEmpty).join(' · ')),
                onTap: () => Navigator.pop(ctx, e.id),
              )),
        ]),
      ),
    );
    if (chosen == null) return;
    await _run(() => ref.read(serviceRepositoryProvider).assignTechnician(t.id, chosen), success: 'Technician assigned');
  }

  Future<void> _raiseEstimate(ServiceTicket t) async {
    final amtCtrl = TextEditingController(text: t.estimateAmount?.toStringAsFixed(2) ?? '');
    final notesCtrl = TextEditingController(text: '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Raise estimate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(controller: amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Estimate amount', prefixText: '₹ ', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Scope / notes', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Send for approval'))),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amtCtrl.text.trim());
    if (amt == null || amt < 0) { _snack('Enter a valid amount', error: true); return; }
    await _run(() => ref.read(serviceRepositoryProvider).raiseEstimate(t.id, amount: amt, notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim()), success: 'Estimate sent');
  }

  Future<void> _approveEstimate(ServiceTicket t) async {
    final byCtrl = TextEditingController(text: t.customerName == '—' ? '' : t.customerName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record approval'),
        content: TextField(controller: byCtrl, decoration: const InputDecoration(labelText: 'Approved by', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(serviceRepositoryProvider).approveEstimate(t.id, respondedBy: byCtrl.text.trim().isEmpty ? null : byCtrl.text.trim()), success: 'Estimate approved');
  }

  // ─── Parts ───
  Widget _partsSection(ServiceTicket t) {
    final suggested = _triage?.suggestedParts ?? const [];
    return _section('Spare Parts', [
      if (t.parts.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No parts added.', style: TextStyle(color: AppColors.textSecondary))),
      // AI-suggested parts (from the diagnosis) — tap to look them up & add.
      if (t.isOpen && suggested.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C3AED)),
            const SizedBox(width: 5),
            const Text('AI-suggested parts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
          ]),
        ),
        Wrap(spacing: 6, runSpacing: 6, children: suggested.map((p) => ActionChip(
              avatar: const Icon(Icons.add, size: 15, color: Color(0xFF6D28D9)),
              label: Text(p, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6D28D9), fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFFF5F3FF),
              side: const BorderSide(color: Color(0xFFDDD6FE)),
              onPressed: _busy ? null : () => _addPart(t, query: p),
            )).toList()),
        const Divider(height: 20),
      ],
      ...t.parts.map((p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${p.quantity.toStringAsFixed(p.quantity == p.quantity.roundToDouble() ? 0 : 2)} ${p.unit ?? ''} × ${CurrencyUtils.format(p.unitPrice)}${p.posted ? '  · issued' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
                Text(CurrencyUtils.format(p.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (t.isOpen && !p.posted)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                    onPressed: _busy ? null : () => _run(() => ref.read(serviceRepositoryProvider).removePart(t.id, p.id), success: 'Part removed'),
                  ),
              ],
            ),
          )),
    ], trailing: t.isOpen
        ? TextButton.icon(onPressed: _busy ? null : () => _addPart(t), icon: const Icon(Icons.add, size: 18), label: const Text('Add'))
        : null);
  }

  // ─── Photos / attachments ───
  Widget _photosSection(ServiceTicket t) {
    final async = ref.watch(ticketAttachmentsProvider(t.id));
    return _section('Photos & Handover', [
      async.when(
        loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
        error: (e, _) => Text('Could not load photos', style: const TextStyle(color: AppColors.textSecondary)),
        data: (atts) => atts.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No photos yet.', style: TextStyle(color: AppColors.textSecondary)))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: atts.map((a) => _thumb(a)).toList(),
              ),
      ),
    ], trailing: t.isOpen
        ? TextButton.icon(onPressed: _busy ? null : () => _capturePhoto(t), icon: const Icon(Icons.add_a_photo_outlined, size: 18), label: const Text('Photo'))
        : null);
  }

  Widget _thumb(ServiceAttachment a) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: a.url == null
              ? Container(width: 84, height: 84, color: AppColors.divider, child: const Icon(Icons.image_not_supported_outlined))
              : CachedNetworkImage(
                  imageUrl: a.url!,
                  width: 84, height: 84, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(width: 84, height: 84, color: AppColors.divider),
                  errorWidget: (_, __, ___) => Container(width: 84, height: 84, color: AppColors.divider, child: const Icon(Icons.broken_image_outlined)),
                ),
        ),
        const SizedBox(height: 2),
        Text(a.kind, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─── Charges / billing ───
  Widget _chargesSection(ServiceTicket t, bool canBill) {
    if (!t.isChargeable) {
      return _section('Charges', [const Text('Non-chargeable (in warranty).', style: TextStyle(color: AppColors.textSecondary))]);
    }
    return _section('Charges', [
      _kv('Labour', CurrencyUtils.format(t.labourCharge)),
      _kv('Parts', CurrencyUtils.format(t.partsCharge)),
      if (t.taxPercent > 0) _kv('Tax', '${t.taxPercent.toStringAsFixed(0)}%'),
      _kv('Total', CurrencyUtils.format(t.totalCharge)),
      if (t.advanceAmount > 0) _kv('Advance', CurrencyUtils.format(t.advanceAmount)),
      _kv('Paid', CurrencyUtils.format(t.paidAmount)),
      _kv('Balance', CurrencyUtils.format(t.balanceAmount)),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          const Text('Status: ', style: TextStyle(color: AppColors.textSecondary)),
          Text(t.paymentStatus, style: TextStyle(fontWeight: FontWeight.w700, color: t.paymentStatus == 'Paid' ? AppColors.success : AppColors.warning)),
        ]),
      ),
      if (canBill)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (t.balanceAmount > 0)
              OutlinedButton.icon(onPressed: _busy ? null : () => _recordPayment(t), icon: const Icon(Icons.payments_outlined, size: 18), label: const Text('Payment')),
            if (t.invoiceId == null && ['READY', 'DELIVERED'].contains(t.status))
              ElevatedButton.icon(onPressed: _busy ? null : () => _raiseInvoice(t), icon: const Icon(Icons.receipt_long, size: 18), label: const Text('Invoice')),
            if (t.invoiceId != null) const Text('Invoiced ✓', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }

  // ─── Timeline ───
  Widget _timeline(ServiceTicket t) {
    return _section('History', [
      if (t.events.isEmpty) const Text('No history.', style: TextStyle(color: AppColors.textSecondary)),
      ...t.events.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 4, right: 8), child: Icon(Icons.circle, size: 8, color: AppColors.primary)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${e.fromStatus != null ? '${ServiceStatus.label(e.fromStatus!)} → ' : ''}${ServiceStatus.label(e.toStatus)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if ((e.note ?? '').isNotEmpty) Text(e.note!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  Text(AppDateUtils.formatWithTime(e.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
            ]),
          )),
    ]);
  }

  // ─── Bottom action bar (status change + handover) ───
  Widget _bottomBar(ServiceTicket t, List<String> nexts, bool canBill) {
    if (nexts.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: BoxDecoration(color: AppColors.surface, border: const Border(top: BorderSide(color: AppColors.border)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))]),
        child: SafeArea(
          top: false,
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _changeStatus(t, nexts),
                icon: const Icon(Icons.sync_alt),
                label: const Text('Change status'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ════════════ Action sheets ════════════

  Future<void> _changeStatus(ServiceTicket t, List<String> nexts) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Move ticket to…', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ...nexts.map((s) => ListTile(
                leading: Icon(Icons.arrow_forward, color: ServiceStatus.color(s)),
                title: Text(ServiceStatus.label(s)),
                onTap: () => Navigator.pop(ctx, s),
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null) return;
    if (choice == 'DELIVERED') {
      await _handover(t);
    } else {
      await _run(() => ref.read(serviceRepositoryProvider).changeStatus(t.id, choice), success: 'Moved to ${ServiceStatus.label(choice)}');
    }
  }

  /// DELIVERED → capture who collected + a signature, upload it as a HANDOVER attachment, then set status.
  Future<void> _handover(ServiceTicket t) async {
    final controller = SignatureController(penStrokeWidth: 2.5, penColor: AppColors.textPrimary, exportBackgroundColor: Colors.white);
    final nameCtrl = TextEditingController(text: t.customerName == '—' ? '' : t.customerName);
    final contactCtrl = TextEditingController(text: t.customer?.phone ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Handover & delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Collected by', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact / ID', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              const Text('Customer signature', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                child: Signature(controller: controller, height: 160, backgroundColor: const Color(0xFFF4F6F8)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(onPressed: () => setS(() => controller.clear()), icon: const Icon(Icons.refresh, size: 18), label: const Text('Clear')),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Confirm delivery'),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );

    if (ok != true) {
      controller.dispose();
      return;
    }

    await _run(() async {
      // 1) Upload the signature image (if drawn).
      if (controller.isNotEmpty) {
        final bytes = await controller.toPngBytes();
        if (bytes != null) {
          final dir = await getTemporaryDirectory();
          final f = File('${dir.path}/handover_${t.id}_${DateTime.now().millisecondsSinceEpoch}.png');
          await f.writeAsBytes(bytes);
          await ref.read(serviceRepositoryProvider).uploadAttachment(t.id, f.path, kind: 'HANDOVER', note: 'Customer signature');
        }
      }
      // 2) Mark delivered with handover details.
      return ref.read(serviceRepositoryProvider).changeStatus(
            t.id, 'DELIVERED',
            deliveredTo: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
            deliveryContact: contactCtrl.text.trim().isEmpty ? null : contactCtrl.text.trim(),
            deliveryNote: 'Signed handover',
          );
    }, success: 'Delivered ✓');
    controller.dispose();
  }

  Future<void> _capturePhoto(ServiceTicket t) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('From gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 70);
    if (picked == null || !mounted) return;
    // Choose a kind based on lifecycle: before READY = INTAKE/REPAIR, else OTHER.
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final k in const ['INTAKE', 'REPAIR', 'OTHER'])
            ListTile(title: Text(k[0] + k.substring(1).toLowerCase()), onTap: () => Navigator.pop(ctx, k)),
        ]),
      ),
    );
    if (kind == null) return;
    await _run(() => ref.read(serviceRepositoryProvider).uploadAttachment(t.id, picked.path, kind: kind), success: 'Photo added');
  }

  Future<void> _addPart(ServiceTicket t, {String? query}) async {
    final result = await showModalBottomSheet<_PartPick>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddPartSheet(repoRef: ref, initialSearch: query),
    );
    if (result == null) return;
    await _run(() => ref.read(serviceRepositoryProvider).addPart(t.id, inventoryItemId: result.item.id, quantity: result.qty, unitPrice: result.price), success: 'Part added');
  }

  Future<void> _recordPayment(ServiceTicket t) async {
    final amtCtrl = TextEditingController(text: t.balanceAmount > 0 ? t.balanceAmount.toStringAsFixed(2) : '');
    String mode = 'Cash';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Record payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(controller: amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Mode', border: OutlineInputBorder()),
                items: const ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => mode = v ?? 'Cash',
              ),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Save'))),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amtCtrl.text.trim());
    if (amt == null || amt <= 0) { _snack('Enter a valid amount', error: true); return; }
    await _run(() => ref.read(serviceRepositoryProvider).recordPayment(t.id, amount: amt, paymentMode: mode), success: 'Payment recorded');
  }

  Future<void> _raiseInvoice(ServiceTicket t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raise GST invoice?'),
        content: Text('Convert ${t.ticketNumber} (${CurrencyUtils.format(t.totalCharge)}) into a GST invoice and post it to the books.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Raise')),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await _run(() => ref.read(serviceRepositoryProvider).createInvoice(t.id));
    if (res != null) _snack('Invoice ${res['invoiceNo'] ?? ''} created');
  }

  Future<void> _editDiagnosis(ServiceTicket t) async {
    final diagCtrl = TextEditingController(text: t.diagnosis ?? '');
    final resCtrl = TextEditingController(text: t.resolution ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Update diagnosis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(controller: diagCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Diagnosis', border: OutlineInputBorder(), alignLabelWithHint: true)),
            const SizedBox(height: 10),
            TextField(controller: resCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Resolution', border: OutlineInputBorder(), alignLabelWithHint: true)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Save'))),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(serviceRepositoryProvider).updateTicket(t.id, {'diagnosis': diagCtrl.text.trim(), 'resolution': resCtrl.text.trim()}), success: 'Updated');
  }

  // ─── Read-only estimate (technician view) ───
  Widget _estimateInfoSection(ServiceTicket t) {
    final s = t.estimateStatus;
    final color = s == 'APPROVED' ? AppColors.success : (s == 'REJECTED' ? AppColors.danger : AppColors.warning);
    final headline = s == 'APPROVED'
        ? 'Customer approved — OK to proceed with the repair.'
        : s == 'REJECTED'
            ? 'Customer rejected the estimate — check with the office before doing chargeable work.'
            : 'Awaiting customer approval — hold chargeable work until approved.';
    return _section('Estimate', [
      Row(children: [
        Icon(s == 'APPROVED' ? Icons.check_circle : (s == 'REJECTED' ? Icons.cancel : Icons.hourglass_top), size: 18, color: color),
        const SizedBox(width: 6),
        Text(s, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        if (t.estimateAmount != null) ...[
          const SizedBox(width: 8),
          Text(CurrencyUtils.format(t.estimateAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ]),
      const SizedBox(height: 6),
      Text(headline, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
      if ((t.estimateNotes ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Scope: ${t.estimateNotes}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
    ]);
  }

  // ─── Job sheet (printable on-site reference) ───
  Future<void> _showJobSheet(ServiceTicket t) async {
    final data = await _run(() => ref.read(serviceRepositoryProvider).jobSheet(t.id));
    if (data == null || !mounted) return;
    final company = (data['company'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tk = (data['ticket'] as Map?)?.cast<String, dynamic>() ?? const {};
    final parts = (tk['parts'] as List? ?? const []).cast<Map>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.85, maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Text(company['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            if ((company['phone'] ?? '').toString().isNotEmpty) Center(child: Text(company['phone'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            const Divider(height: 24),
            Center(child: Text('JOB SHEET · ${t.ticketNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5))),
            const SizedBox(height: 14),
            _kv('Customer', t.customerName),
            if ((t.customer?.phone ?? '').isNotEmpty) _kv('Phone', t.customer!.phone!),
            if (t.serviceItem != null) ...[
              _kv('Device', t.serviceItem!.label),
              if (t.serviceItem!.serialNumber != null) _kv('Serial', t.serviceItem!.serialNumber!),
            ],
            _kv('Type', ServiceStatus.serviceTypeLabel(t.serviceType)),
            _kv('Status', ServiceStatus.label(t.status)),
            _kv('Reported', AppDateUtils.formatDisplay(t.reportedAt)),
            if (t.promisedAt != null) _kv('Promised', AppDateUtils.formatDisplay(t.promisedAt)),
            const Divider(height: 24),
            _kv('Problem', t.reportedProblem),
            if ((t.intakeCondition ?? '').isNotEmpty) _kv('Intake condition', t.intakeCondition!),
            if (t.accessories.isNotEmpty) _kv('Accessories', t.accessories.join(', ')),
            if ((t.diagnosis ?? '').isNotEmpty) _kv('Diagnosis', t.diagnosis!),
            if (parts.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Parts', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...parts.map((p) {
                final item = (p['item'] as Map?)?.cast<String, dynamic>();
                return _kv(item?['itemName']?.toString() ?? 'Part', '${p['quantity']} × ₹${p['unitPrice']}');
              }),
            ],
            if (t.isChargeable) ...[
              const Divider(height: 24),
              _kv('Labour', CurrencyUtils.format(t.labourCharge)),
              _kv('Total', CurrencyUtils.format(t.totalCharge)),
              if (t.advanceAmount > 0) _kv('Advance', CurrencyUtils.format(t.advanceAmount)),
              _kv('Balance', CurrencyUtils.format(t.balanceAmount)),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── Service certificate / report (post-completion proof of work) ───
  Future<void> _showCertificate(ServiceTicket t) async {
    final r = await _run(() => ref.read(serviceRepositoryProvider).serviceReport(t.id));
    if (r == null || !mounted) return;
    final parts = (r['parts'] as List? ?? const []).cast<Map>();
    final charges = (r['charges'] as Map?)?.cast<String, dynamic>() ?? const {};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.85, maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Text(r['company']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            const SizedBox(height: 4),
            const Center(child: Text('SERVICE REPORT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.2))),
            Center(child: Text(r['ticketNumber']?.toString() ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
            const Divider(height: 24),
            if ((r['aiSummary'] ?? '').toString().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                child: Text(r['aiSummary'].toString(), style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            _kv('Status', (r['statusLabel'] ?? r['status'] ?? '').toString()),
            _kv('Warranty', (r['warrantyLabel'] ?? '').toString()),
            _kv('Problem', (r['reportedProblem'] ?? '').toString()),
            if ((r['diagnosis'] ?? '').toString().isNotEmpty) _kv('Diagnosis', r['diagnosis'].toString()),
            if ((r['resolution'] ?? '').toString().isNotEmpty) _kv('Resolution', r['resolution'].toString()),
            if (parts.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Parts used', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...parts.map((p) => _kv(p['name']?.toString() ?? 'Part', '${p['qty']}${p['unit'] != null ? ' ${p['unit']}' : ''} · ₹${p['lineTotal']}')),
            ],
            if (r['isChargeable'] == true) ...[
              const Divider(height: 24),
              _kv('Labour', '₹${charges['labour'] ?? 0}'),
              _kv('Parts', '₹${charges['partsTotal'] ?? 0}'),
              _kv('Total', '₹${charges['total'] ?? 0}'),
              _kv('Paid', '₹${charges['paid'] ?? 0}'),
              _kv('Balance', '₹${charges['balance'] ?? 0}'),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── Share the public repair-tracking link with the customer ───
  Future<void> _shareTracking(ServiceTicket t) async {
    final r = await _run(() => ref.read(serviceRepositoryProvider).shareLink(t.id));
    if (r == null || !mounted) return;
    final url = '${ApiConstants.webBaseUrl}${r['trackPath']}';
    final msg = 'Track your repair ${t.ticketNumber} here: $url';
    final phone = (t.customer?.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Share tracking link', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(url, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy link'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) Navigator.pop(ctx);
              _snack('Link copied');
            },
          ),
          if (phone.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Send on WhatsApp'),
              onTap: () async {
                final wa = Uri.parse('https://wa.me/91$phone?text=${Uri.encodeComponent(msg)}');
                if (await canLaunchUrl(wa)) await launchUrl(wa, mode: LaunchMode.externalApplication);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          if (phone.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Send SMS'),
              onTap: () async {
                final sms = Uri.parse('sms:$phone?body=${Uri.encodeComponent(msg)}');
                if (await canLaunchUrl(sms)) await launchUrl(sms);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ─── AI diagnosis help mid-job (triage suggestion for the technician) ───
  // ─── Inline AI diagnosis (probable causes / suggested parts / checklist) ───
  Future<void> _runTriage(ServiceTicket t) async {
    setState(() => _triaging = true);
    try {
      final triage = await ref.read(serviceRepositoryProvider).aiTriage(
            reportedProblem: [t.reportedProblem, if ((t.diagnosis ?? '').isNotEmpty) 'Current diagnosis: ${t.diagnosis}'].join('\n'),
            category: t.serviceItem?.category,
            brand: t.serviceItem?.brand,
            modelName: t.serviceItem?.modelName,
            underWarranty: !t.isChargeable,
          );
      if (mounted) setState(() => _triage = triage);
    } catch (e) {
      final msg = e.toString().toLowerCase().contains('not configured')
          ? "AI Assist isn't configured on the server (missing OpenAI key)."
          : e.toString();
      _snack(msg, error: true);
    } finally {
      if (mounted) setState(() => _triaging = false);
    }
  }

  Widget _aiDiagnosisSection(ServiceTicket t) {
    final tri = _triage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          const Expanded(child: Text('AI Diagnosis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF6D28D9)))),
          if (tri != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFDDD6FE))),
              child: Text(ServiceStatus.label(tri.priority), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
            ),
        ]),
        if (tri == null) ...[
          const SizedBox(height: 6),
          const Text('Get AI-suggested causes, likely parts and a diagnostic checklist for this repair.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _pillButton(
              _triaging ? 'Analysing…' : 'Get AI diagnosis',
              _triaging ? null : () => _runTriage(t),
              busy: _triaging,
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          if (tri.faultCategory.isNotEmpty) _aiLine('Fault', tri.faultCategory),
          if (tri.estimatedLabour > 0) _aiLine('Est. labour', CurrencyUtils.format(tri.estimatedLabour.toDouble())),
          if (tri.estimatedTurnaroundDays != null) _aiLine('Turnaround', '${tri.estimatedTurnaroundDays} day(s)'),
          if (tri.probableCauses.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Probable causes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF4C1D95))),
            const SizedBox(height: 2),
            ...tri.probableCauses.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text('•  $c', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)))),
          ],
          if (tri.suggestedParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Likely parts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF4C1D95))),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: tri.suggestedParts.map((p) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFDDD6FE))),
                  child: Text(p, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6D28D9), fontWeight: FontWeight.w600)),
                )).toList()),
            if (t.isOpen)
              const Padding(padding: EdgeInsets.only(top: 4), child: Text('Add these from Spare Parts below.', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
          ],
          if (tri.diagnosticChecklist.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Diagnostic checklist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF4C1D95))),
            const SizedBox(height: 2),
            ...tri.diagnosticChecklist.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text('☐  $c', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)))),
          ],
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(child: Text('AI suggestion — verify before acting.', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontStyle: FontStyle.italic))),
            TextButton(
              onPressed: _triaging ? null : () => _runTriage(t),
              style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8), foregroundColor: const Color(0xFF6D28D9)),
              child: const Text('Refresh', style: TextStyle(fontSize: 12.5)),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _aiLine(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 92, child: Text(k, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        ]),
      );

  // Plain tappable pill (avoids Material-button rendering quirks in scroll views).
  Widget _pillButton(String label, VoidCallback? onTap, {bool busy = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onTap == null ? const Color(0xFFA78BDA) : const Color(0xFF7C3AED),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.auto_awesome, size: 17, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      );

  // ─── small layout helpers ───
  // ════════════ Warranty RMA (F2) ════════════

  Widget _reworkBadge(String text, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(text, style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _rmaSection(ServiceTicket t) {
    return _section('Warranty RMA · Company replacement', [
      if (t.rmas.isEmpty)
        const Text('Nothing sent to the company yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ...t.rmas.map((r) => _rmaCard(t, r)),
    ], trailing: t.canSendRma
        ? TextButton.icon(onPressed: _busy ? null : () => _sendRmaSheet(t), icon: const Icon(Icons.local_shipping_outlined, size: 18), label: const Text('Send'))
        : null);
  }

  Widget _rmaCard(ServiceTicket t, ServiceTicketRma r) {
    final c = r.status == 'SENT' ? AppColors.warning : (r.status == 'RECEIVED' ? AppColors.success : AppColors.textSecondary);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.rmaNumber, style: const TextStyle(fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(r.outcome != 'PENDING' ? '${r.status} · ${r.outcome}' : r.status, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        _kv('Company', r.company),
        if (r.outboundRef != null) _kv('Docket / Ref', r.outboundRef!),
        if (r.sentAt != null) _kv('Sent', AppDateUtils.formatDisplay(r.sentAt)),
        if (r.expectedReturnAt != null) _kv('Expected back', AppDateUtils.formatDisplay(r.expectedReturnAt)),
        if (r.receivedAt != null) _kv('Received', AppDateUtils.formatDisplay(r.receivedAt)),
        if (r.replacementSerial != null) _kv('Replacement serial', r.replacementSerial!),
        if (r.reclaimAmount != null) _kv('Reclaimed', CurrencyUtils.format(r.reclaimAmount)),
        if (r.status == 'SENT')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _receiveRmaSheet(t, r),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Mark received from company'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
            ),
          ),
      ]),
    );
  }

  Future<void> _sendRmaSheet(ServiceTicket t) async {
    final companyCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime? expected;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Send to manufacturer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Opens a company RMA · ticket → Sent to manufacturer', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'Manufacturer / company *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Company RMA / docket ref', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setS(() => expected = d);
                  },
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(expected == null ? 'Expected back by (optional)' : 'Back by ${AppDateUtils.formatDisplay(expected)}'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (companyCtrl.text.trim().isEmpty) { _snack('Enter the manufacturer / company name.', error: true); return; }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Dispatch to company'),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref.read(serviceRepositoryProvider).sendRma(
            t.id,
            companyName: companyCtrl.text.trim(),
            outboundRef: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
            expectedReturnAt: expected,
            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          ),
      success: 'Sent to company ✓',
    );
  }

  Future<void> _receiveRmaSheet(ServiceTicket t, ServiceTicketRma r) async {
    var outcome = 'REPLACED';
    final serialCtrl = TextEditingController();
    final reclaimCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final canBill = ref.read(authProvider).user?.canBill == true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Receive ${r.rmaNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              const Text('Outcome', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: ['REPLACED', 'REPAIRED', 'REJECTED'].map((o) => ChoiceChip(label: Text(o), selected: outcome == o, onSelected: (_) => setS(() => outcome = o))).toList()),
              if (outcome == 'REPLACED') ...[
                const SizedBox(height: 12),
                TextField(controller: serialCtrl, decoration: const InputDecoration(labelText: 'Replacement serial / IMEI', border: OutlineInputBorder())),
              ],
              if (canBill) ...[
                const SizedBox(height: 12),
                TextField(controller: reclaimCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cost reclaimed from company', prefixText: '₹ ', border: OutlineInputBorder())),
              ],
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Mark received & resume'),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref.read(serviceRepositoryProvider).receiveRma(
            t.id, r.id,
            outcome: outcome,
            replacementSerial: serialCtrl.text.trim(),
            reclaimAmount: double.tryParse(reclaimCtrl.text.trim()),
            notes: notesCtrl.text.trim(),
          ),
      success: 'Received from company ✓',
    );
  }

  // ════════════ Rework (F3) ════════════

  Future<void> _reworkSheet(ServiceTicket t) async {
    final reasonCtrl = TextEditingController();
    var chargeable = false;
    final canBill = ref.read(authProvider).user?.canBill == true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reopen for rework', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Creates a new ticket linked to ${t.ticketNumber}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Why is it back? (reason) *', border: OutlineInputBorder()), maxLines: 3),
              if (canBill)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: chargeable,
                  onChanged: (v) => setS(() => chargeable = v),
                  title: const Text('Charge for this rework'),
                  subtitle: const Text('Off by default — rework is usually free'),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (reasonCtrl.text.trim().isEmpty) { _snack('Enter a reason for the rework.', error: true); return; }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Create rework ticket'),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final result = await _run(
      () => ref.read(serviceRepositoryProvider).rework(t.id, reason: reasonCtrl.text.trim(), isChargeable: chargeable),
      success: 'Rework ticket created',
    );
    if (result != null && mounted) context.push('/service/tickets/${result.id}');
  }

  Widget _section(String title, List<Widget> children, {Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary))),
        ]),
      );
}

// ─── Add-part bottom sheet (searches parts-catalog) ───
class _PartPick {
  final PartCatalogItem item;
  final double qty;
  final double price;
  _PartPick(this.item, this.qty, this.price);
}

class _AddPartSheet extends ConsumerStatefulWidget {
  final WidgetRef repoRef;
  final String? initialSearch;
  const _AddPartSheet({required this.repoRef, this.initialSearch});
  @override
  ConsumerState<_AddPartSheet> createState() => _AddPartSheetState();
}

class _AddPartSheetState extends ConsumerState<_AddPartSheet> {
  final _searchCtrl = TextEditingController();
  List<PartCatalogItem> _items = [];
  bool _loading = false;
  PartCatalogItem? _selected;
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final q = widget.initialSearch ?? '';
    _searchCtrl.text = q;
    _search(q);
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final items = await ref.read(serviceRepositoryProvider).partsCatalog(search: q);
      if (mounted) setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add spare part', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(labelText: 'Search parts', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (v) => _search(v),
          ),
          const SizedBox(height: 8),
          if (_loading) const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))))
          else SizedBox(
            height: 180,
            child: ListView(
              children: _items.map((p) {
                final selected = identical(_selected, p);
                return ListTile(
                  dense: true,
                  selected: selected,
                  leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? AppColors.primary : AppColors.textMuted),
                  title: Text(p.itemName),
                  subtitle: Text('${p.itemCode ?? ''} · ${p.unit ?? ''}'),
                  onTap: () => setState(() {
                    _selected = p;
                    if (_priceCtrl.text.isEmpty && p.defaultUnitCost > 0) _priceCtrl.text = p.defaultUnitCost.toStringAsFixed(2);
                  }),
                );
              }).toList(),
            ),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _qtyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit price', prefixText: '₹ ', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
                  final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
                  if (qty <= 0) return;
                  Navigator.pop(context, _PartPick(_selected!, qty, price));
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Add part'),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

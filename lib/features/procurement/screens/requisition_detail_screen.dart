import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/procurement_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/procurement_providers.dart';
import '../widgets/procurement_list_view.dart';

/// Material Requisition detail — read-only lines + status, with the trivial
/// lifecycle actions (Submit / Approve / Reject) the web detail also exposes.
class RequisitionDetailScreen extends ConsumerStatefulWidget {
  const RequisitionDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<RequisitionDetailScreen> createState() => _RequisitionDetailScreenState();
}

class _RequisitionDetailScreenState extends ConsumerState<RequisitionDetailScreen> {
  bool _busy = false;

  Future<void> _act(String action, {String? reason}) async {
    setState(() => _busy = true);
    final repo = ref.read(procurementRepositoryProvider);
    try {
      switch (action) {
        case 'submit':
          await repo.submitRequisition(widget.id);
          break;
        case 'approve':
          await repo.approveRequisition(widget.id);
          break;
        case 'reject':
          await repo.rejectRequisition(widget.id, reason ?? 'Rejected');
          break;
      }
      ref.invalidate(requisitionDetailProvider(widget.id));
      // Refresh the hub counts/lists in the background.
      ref.read(procurementHubProvider.notifier).load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requisition $action${action == 'submit' ? 'ted' : 'd'}.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.startsWith('Exception: ') ? s.substring(11) : s), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject requisition'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g. duplicate request'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? 'Rejected' : ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason != null) _act('reject', reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(requisitionDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Requisition')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(requisitionDetailProvider(widget.id)),
        ),
        data: (mr) => _body(mr),
      ),
    );
  }

  Widget _body(Requisition mr) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(requisitionDetailProvider(widget.id)),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _headerCard(mr),
          if (mr.status == 'REJECTED' && (mr.rejectionReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _banner('Rejected: ${mr.rejectionReason}', AppColors.danger),
          ],
          if ((mr.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _banner(mr.notes!, AppColors.info),
          ],
          const SizedBox(height: 14),
          _itemsCard(mr),
          const SizedBox(height: 16),
          _actions(mr),
        ],
      ),
    );
  }

  Widget _headerCard(Requisition mr) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(mr.mrNumber.isEmpty ? 'Requisition' : mr.mrNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                ProcStatusPill(mr.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                AppDateUtils.formatDisplay(mr.requisitionDate),
                if ((mr.department ?? '').isNotEmpty) mr.department!,
                'Priority ${mr.priority}',
              ].join('  ·  '),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            if (mr.requiredByDate != null) ...[
              const SizedBox(height: 3),
              Text('Required by ${AppDateUtils.formatDisplay(mr.requiredByDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ],
        ),
      );

  Widget _itemsCard(Requisition mr) => Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('Items / Materials', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
            ),
            const Divider(height: 1),
            ...mr.items.asMap().entries.map((e) {
              final it = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(width: 22, child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                    Expanded(child: Text(it.itemDescription, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary))),
                    const SizedBox(width: 8),
                    Text('${fmtQty(it.quantity)} ${it.unit}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ],
                ),
              );
            }),
            if (mr.items.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('No line items.', style: TextStyle(color: AppColors.textMuted))),
            const SizedBox(height: 6),
          ],
        ),
      );

  Widget _actions(Requisition mr) {
    final buttons = <Widget>[];
    if (mr.status == 'DRAFT') {
      buttons.add(_fill('Submit for approval', AppColors.primary, () => _act('submit')));
    } else if (mr.status == 'SUBMITTED') {
      buttons.add(_fill('Approve', AppColors.success, () => _act('approve')));
      buttons.add(_outline('Reject', AppColors.danger, _reject));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 10, children: buttons);
  }

  Widget _fill(String label, Color c, VoidCallback onTap) => FilledButton(
        onPressed: _busy ? null : onTap,
        style: FilledButton.styleFrom(backgroundColor: c, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        child: Text(label),
      );

  Widget _outline(String label, Color c, VoidCallback onTap) => OutlinedButton(
        onPressed: _busy ? null : onTap,
        style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: c.withValues(alpha: 0.5)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        child: Text(label),
      );

  Widget _banner(String text, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Text(text, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
      );
}

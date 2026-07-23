import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/machine_detail_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/machinery_providers.dart';
import 'erp_common.dart';

const _accent = Color(0xFF7C3AED);
const _amber = Color(0xFFF59E0B);

/// Machine detail for the field: meter + status, Log-usage / Report-breakdown actions,
/// service due, documents (expiry), jobs (manager can approve) and recent logs.
/// The backend already strips costs & commercial data for the operator role.
class MachineDetailScreen extends ConsumerWidget {
  final int machineId;
  const MachineDetailScreen({super.key, required this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(machineDetailProvider(machineId));
    final user = ref.watch(authProvider).user;
    final canApprove = user?.isAdmin == true || user?.isSiteAdmin == true; // site L1 + managers/admins

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Machine'),
        actions: [
          if (user?.isOperator != true)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final saved = await context.push<bool>('/machinery/$machineId/edit');
                if (saved == true) ref.invalidate(machineDetailProvider(machineId));
              },
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingIndicator(message: 'Loading machine…'),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(machineDetailProvider(machineId))),
        data: (m) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(machineDetailProvider(machineId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _headerCard(m),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _pill(context, 'Log today\'s usage', Icons.edit_note, Colors.white, AppColors.primary, () async {
                  final saved = await context.push<bool>('/machinery/$machineId/log');
                  if (saved == true) ref.invalidate(machineDetailProvider(machineId));
                })),
                const SizedBox(width: 10),
                Expanded(child: _pill(context, 'Report breakdown', Icons.report_problem_outlined, Colors.white, AppColors.danger, () async {
                  final saved = await context.push<bool>('/machinery/$machineId/breakdown');
                  if (saved == true) ref.invalidate(machineDetailProvider(machineId));
                })),
              ]),
              const SizedBox(height: 18),
              if (m.schedules.isNotEmpty) ...[
                _sectionTitle('Service due'),
                ...m.schedules.map((s) => _scheduleTile(s, m)),
                const SizedBox(height: 14),
              ],
              if (m.documents.isNotEmpty) ...[
                _sectionTitle('Documents'),
                ...m.documents.map(_docTile),
                const SizedBox(height: 14),
              ],
              if (m.jobs.isNotEmpty) ...[
                _sectionTitle('Maintenance jobs'),
                ...m.jobs.take(8).map((j) => _JobTile(job: j, canApprove: canApprove, machineId: machineId)),
                const SizedBox(height: 14),
              ],
              if (m.logs.isNotEmpty) ...[
                _sectionTitle('Recent logbook'),
                ...m.logs.take(10).map((l) => _logTile(l, m.meterUnit)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard(MachineDetail m) {
    final statusColor = ErpCard.statusColor(m.status);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_accent, Color(0xFF6D28D9)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(m.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text('${m.machineCode}${(m.make ?? '').isNotEmpty ? ' · ${m.make} ${m.model ?? ''}' : ''}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
              child: Text(m.status.replaceAll('_', ' '), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor == AppColors.danger ? const Color(0xFFFECACA) : Colors.white)),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('${m.currentMeter % 1 == 0 ? m.currentMeter.toInt() : m.currentMeter} ${m.meterUnit}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                Text('Current meter', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
              ]),
            ),
            if ((m.currentLocation ?? '').isNotEmpty)
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(m.currentLocation!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Location', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
                ]),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      );

  Widget _scheduleTile(MachineSchedule s, MachineDetail m) {
    final due = s.isDue(m.currentMeter);
    final subtitle = s.basis == 'METER'
        ? 'At ${s.nextDueMeter?.toInt() ?? '—'} ${m.meterUnit} (now ${m.currentMeter.toInt()})'
        : (s.nextDueDate != null ? 'Due ${_fmtDate(s.nextDueDate!)}' : 'No date set');
    return _tile(
      icon: due ? Icons.build_circle : Icons.schedule,
      color: due ? AppColors.danger : AppColors.textMuted,
      title: s.title,
      subtitle: subtitle,
      trailing: due ? _chip('DUE NOW', AppColors.danger) : null,
    );
  }

  Widget _docTile(MachineDoc d) {
    final days = d.daysToExpiry;
    Color c = AppColors.success;
    String label = 'Valid';
    if (days != null) {
      if (days < 0) { c = AppColors.danger; label = 'EXPIRED'; }
      else if (days <= 30) { c = _amber; label = 'In $days d'; }
      else { label = _fmtDate(d.expiryDate!); }
    }
    return _tile(
      icon: Icons.description_outlined,
      color: c,
      title: d.docType.replaceAll('_', ' '),
      subtitle: d.docNumber ?? '—',
      trailing: _chip(label, c),
    );
  }

  Widget _logTile(MachineLog l, String unit) => _tile(
        icon: Icons.edit_note,
        color: AppColors.textMuted,
        title: '${l.logDate != null ? _fmtDate(l.logDate!) : '—'}${(l.shift ?? '').isNotEmpty ? ' · ${l.shift}' : ''}',
        subtitle: '${l.openingMeter.toInt()} → ${l.closingMeter.toInt()} $unit'
            '${l.workingHours != null ? ' · ${l.workingHours!.toStringAsFixed(l.workingHours! % 1 == 0 ? 0 : 1)} hrs' : ''}'
            '${l.fuelQty != null ? ' · ${l.fuelQty!.toStringAsFixed(0)} L' : ''}',
      );

  Widget _tile({required IconData icon, required Color color, required String title, required String subtitle, Widget? trailing}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ]),
      );

  static Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
      );

  Widget _pill(BuildContext context, String label, IconData icon, Color fg, Color bg, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 7),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fg))),
          ]),
        ),
      );

  static String _fmtDate(DateTime d) {
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }
}

class _JobTile extends ConsumerStatefulWidget {
  final MachineJob job;
  final bool canApprove;
  final int machineId;
  const _JobTile({required this.job, required this.canApprove, required this.machineId});
  @override
  ConsumerState<_JobTile> createState() => _JobTileState();
}

class _JobTileState extends ConsumerState<_JobTile> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await ref.read(machineryRepositoryProvider).approveJob(widget.job.id);
      ref.invalidate(machineDetailProvider(widget.machineId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.job.jobCode} approved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final statusColor = switch (j.status) {
      'APPROVED' => AppColors.success,
      'PENDING' => _amber,
      'IN_PROGRESS' => const Color(0xFF0891B2),
      _ => AppColors.textMuted,
    };
    final showApprove = widget.canApprove && !_busy && (j.status == 'PENDING' || j.status == 'COMPLETED');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(j.type == 'BREAKDOWN' ? Icons.report_problem_outlined : Icons.build_outlined, size: 18, color: j.type == 'BREAKDOWN' ? AppColors.danger : AppColors.textMuted),
          const SizedBox(width: 8),
          Text(j.jobCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          MachineDetailScreen._chip(j.status.replaceAll('_', ' '), statusColor),
          const Spacer(),
          if (j.totalCost != null) Text('₹${j.totalCost!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 6),
        Text(j.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (showApprove) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _approve,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.success.withValues(alpha: 0.4))),
              child: const Text('Approve job', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.success)),
            ),
          ),
        ],
      ]),
    );
  }
}

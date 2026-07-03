import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/erp_list_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/erp_providers.dart';
import '../providers/machinery_providers.dart';
import 'erp_common.dart';
import 'machine_transfers_section.dart';

const _accent = Color(0xFF7C3AED);
const _accentDark = Color(0xFF6D28D9);
const _amber = Color(0xFFF59E0B);

/// Machinery field home ("My Machines") — the operator's landing screen, also useful
/// for site admins. Hero with today's counts, quick actions, needs-attention and the
/// machine cards with one-tap Log / Report.
class MachineryHomeScreen extends ConsumerWidget {
  const MachineryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final machinesAsync = ref.watch(machineryListProvider);
    final summaryAsync = ref.watch(machinerySummaryProvider);
    // Operators are blocked from the transfers register (office/commercial); only
    // supervisors+ see the receive queue here.
    final showTransfers = user?.isOperator != true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(machineryListProvider);
            ref.invalidate(machinerySummaryProvider);
            if (showTransfers) ref.invalidate(machineTransfersProvider);
          },
          child: machinesAsync.when(
            loading: () => const LoadingIndicator(message: 'Loading your machines…'),
            error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(machineryListProvider)),
            data: (machines) {
              final summary = summaryAsync.valueOrNull;
              final docsExpiring = summary?.docsExpiring ?? machines.fold<int>(0, (s, m) => s + m.docsExpiring);
              final underMaint = machines.where((m) => m.status == 'UNDER_MAINTENANCE').length;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _hero(user?.name ?? '', machines.length, docsExpiring, summary?.jobsOpen ?? 0),
                  const SizedBox(height: 14),
                  if (docsExpiring > 0 || underMaint > 0) ...[
                    _attentionBanner(docsExpiring, underMaint),
                    const SizedBox(height: 14),
                  ],
                  if (showTransfers) const MachineTransfersSection(),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Text('My machines', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.go('/machinery'),
                        child: const Text('View all', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (machines.isEmpty)
                    const ErpEmpty(icon: Icons.agriculture_outlined, text: 'No machines assigned to you yet.\nAsk your supervisor to assign you as the operator.')
                  else
                    ...machines.map((m) => _MachineCard(machine: m)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _hero(String name, int total, int docsExpiring, int jobsOpen) {
    final now = DateTime.now();
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final greeting = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_accent, _accentDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(children: [
          Positioned(right: -24, top: -24, child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$greeting, ${name.split(' ').first} 👷', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 3),
            Text('${wd[now.weekday - 1]}, ${now.day} ${mo[now.month - 1]}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.78))),
            const SizedBox(height: 16),
            Row(children: [
              _stat('$total', 'My machines'),
              _statDivider(),
              _stat('$docsExpiring', 'Docs expiring'),
              _statDivider(),
              _stat('$jobsOpen', 'Open jobs'),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
        ]),
      );

  Widget _statDivider() => Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.22), margin: const EdgeInsets.symmetric(horizontal: 12));

  Widget _attentionBanner(int docsExpiring, int underMaint) {
    final parts = <String>[
      if (docsExpiring > 0) '$docsExpiring document${docsExpiring == 1 ? '' : 's'} expiring soon',
      if (underMaint > 0) '$underMaint machine${underMaint == 1 ? '' : 's'} under maintenance',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, size: 20, color: _amber),
        const SizedBox(width: 10),
        Expanded(child: Text('Needs attention: ${parts.join(' · ')}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)))),
      ]),
    );
  }
}

class _MachineCard extends StatelessWidget {
  final Machine machine;
  const _MachineCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    final m = machine;
    final statusColor = ErpCard.statusColor(m.status);
    return GestureDetector(
      onTap: () => context.push('/machinery/${m.id}'),
      child: Container(
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
              child: const Icon(Icons.agriculture_outlined, size: 19, color: _accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(m.machineCode, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: Text(m.status.replaceAll('_', ' '), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          if ((m.currentLocation ?? '').isNotEmpty || m.docsExpiring > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              if ((m.currentLocation ?? '').isNotEmpty) ...[
                const Icon(Icons.place_outlined, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Flexible(child: Text(m.currentLocation!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
              ],
              const Spacer(),
              if (m.docsExpiring > 0)
                Text('⚠ ${m.docsExpiring} doc${m.docsExpiring == 1 ? '' : 's'} expiring', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _pill(context, 'Log usage', Icons.edit_note, AppColors.primary, () => context.push('/machinery/${m.id}/log'))),
            const SizedBox(width: 10),
            Expanded(child: _pill(context, 'Report issue', Icons.report_problem_outlined, AppColors.danger, () => context.push('/machinery/${m.id}/breakdown'))),
          ]),
        ]),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11), border: Border.all(color: color.withValues(alpha: 0.35))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );
}

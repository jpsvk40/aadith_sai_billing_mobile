import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/service_contract_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/app_card.dart';
import '../providers/service_providers.dart';

/// AMC preventive-maintenance visits due (Today tab). Mark done, call, or navigate.
class TodayVisitsScreen extends ConsumerWidget {
  const TodayVisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dueVisitsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AMC Visits · 60 days'),
        actions: [IconButton(tooltip: 'Calendar', icon: const Icon(Icons.calendar_month), onPressed: () => context.go('/service/calendar'))],
      ),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(dueVisitsProvider)),
        data: (visits) {
          final pending = visits.where((v) => !v.isDone).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dueVisitsProvider),
            child: pending.isEmpty
                ? ListView(children: const [SizedBox(height: 120), EmptyStateWidget(message: 'No visits due', icon: Icons.event_available)])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: pending.length,
                    itemBuilder: (ctx, i) => _VisitCard(visit: pending[i]),
                  ),
          );
        },
      ),
    );
  }
}

class _VisitCard extends ConsumerStatefulWidget {
  final ContractVisit visit;
  const _VisitCard({required this.visit});
  @override
  ConsumerState<_VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends ConsumerState<_VisitCard> {
  bool _busy = false;

  Future<void> _markDone() async {
    setState(() => _busy = true);
    try {
      final v = widget.visit;
      await ref.read(serviceRepositoryProvider).markVisit(
            v.contractId ?? 0, v.id,
            status: 'DONE',
            completedDate: DateTime.now().toIso8601String(),
          );
      ref.invalidate(dueVisitsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit marked done'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _navigate(String query) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final phone = v.customer?.phone;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(v.customer?.name ?? 'AMC visit', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          if (v.overdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(6)),
              child: const Text('OVERDUE', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 4),
        Text('${v.contractNumber ?? ''} · Visit #${v.sequence}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        Text('Scheduled ${AppDateUtils.formatDisplay(v.scheduledDate)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(children: [
          if (phone != null && phone.isNotEmpty) ...[
            OutlinedButton.icon(onPressed: () => _call(phone), icon: const Icon(Icons.call, size: 16), label: const Text('Call')),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(onPressed: () => _navigate(v.customer?.name ?? ''), icon: const Icon(Icons.directions, size: 16), label: const Text('Navigate')),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _busy ? null : _markDone,
            icon: _busy ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 16),
            label: const Text('Done'),
          ),
        ]),
      ]),
    );
  }
}

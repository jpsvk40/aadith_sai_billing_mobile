import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_contract_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../providers/service_providers.dart';

const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// A visit's time bucket, used both to colour a card and to drive the date filter.
enum _Bucket { overdue, today, week, later }

_Bucket _bucketOf(ContractVisit v) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (v.overdue) return _Bucket.overdue;
  final d = v.scheduledDate;
  if (d == null) return _Bucket.later;
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  if (diff <= 0) return _Bucket.today;
  if (diff <= 7) return _Bucket.week;
  return _Bucket.later;
}

Color _accentOf(_Bucket b) => switch (b) {
      _Bucket.overdue => AppColors.danger,
      _Bucket.today => AppColors.primary,
      _Bucket.week => const Color(0xFFF59E0B),
      _Bucket.later => AppColors.textMuted,
    };

/// Human "when" label + its colour (e.g. "Overdue by 3 days", "Today", "In 2 days").
(String, Color) _relative(ContractVisit v) {
  final b = _bucketOf(v);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = v.scheduledDate;
  final accent = _accentOf(b);
  if (d == null) return ('Unscheduled', accent);
  final sd = DateTime(d.year, d.month, d.day);
  if (b == _Bucket.overdue) {
    final days = today.difference(sd).inDays;
    return (days > 0 ? 'Overdue by $days day${days == 1 ? '' : 's'}' : 'Overdue', accent);
  }
  final diff = sd.difference(today).inDays;
  if (diff <= 0) return ('Today', accent);
  if (diff == 1) return ('Tomorrow', accent);
  return ('In $diff days', accent);
}

/// AMC preventive-maintenance visits due (Today tab). Modern hero + date filters;
/// mark done, call, or navigate.
class TodayVisitsScreen extends ConsumerStatefulWidget {
  const TodayVisitsScreen({super.key});
  @override
  ConsumerState<TodayVisitsScreen> createState() => _TodayVisitsScreenState();
}

class _TodayVisitsScreenState extends ConsumerState<TodayVisitsScreen> {
  String _filter = 'all'; // all | overdue | today | week | later

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dueVisitsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(dueVisitsProvider)),
          data: (visits) {
            final pending = visits.where((v) => !v.isDone).toList()
              ..sort((a, b) => (a.scheduledDate ?? DateTime(2100)).compareTo(b.scheduledDate ?? DateTime(2100)));

            final counts = {
              'overdue': pending.where((v) => _bucketOf(v) == _Bucket.overdue).length,
              'today': pending.where((v) => _bucketOf(v) == _Bucket.today).length,
              'week': pending.where((v) => _bucketOf(v) == _Bucket.week).length,
              'later': pending.where((v) => _bucketOf(v) == _Bucket.later).length,
            };

            final shown = _filter == 'all'
                ? pending
                : pending.where((v) => _bucketOf(v).name == _filter).toList();

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(dueVisitsProvider),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header(context, pending.length, counts['overdue']!, counts['today']!)),
                  SliverToBoxAdapter(
                    child: _FilterBar(
                      selected: _filter,
                      total: pending.length,
                      counts: counts,
                      onSelect: (f) => setState(() => _filter = f),
                    ),
                  ),
                  if (shown.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _empty())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _VisitCard(visit: shown[i])),
                          childCount: shown.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int total, int overdue, int today) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Stack(children: [
            Positioned(right: -30, top: -30, child: _bubble(110)),
            Positioned(right: 44, bottom: -34, child: _bubble(78)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.event_repeat, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('AMC Visits',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                ),
                _iconBtn(Icons.calendar_month, () => context.go('/service/calendar')),
              ]),
              const SizedBox(height: 2),
              Text('Preventive maintenance due · next 60 days',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5)),
              const SizedBox(height: 16),
              Row(children: [
                _stat('$total', 'Due', Colors.white),
                _divider(),
                _stat('$overdue', 'Overdue', overdue > 0 ? const Color(0xFFFECACA) : Colors.white),
                _divider(),
                _stat('$today', 'Today', Colors.white),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _bubble(double s) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)));
  Widget _divider() => Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.22), margin: const EdgeInsets.symmetric(horizontal: 14));

  Widget _stat(String value, String label, Color valueColor) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]);

  Widget _iconBtn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: Colors.white, size: 20)),
        ),
      );

  Widget _empty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: AppColors.successLight, shape: BoxShape.circle),
            child: const Icon(Icons.event_available, size: 40, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          Text(_filter == 'all' ? 'No visits due' : 'Nothing in this range',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Pull down to refresh', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 80),
        ]),
      );
}

/// Horizontally-scrolling date-range pills with live counts.
class _FilterBar extends StatelessWidget {
  final String selected;
  final int total;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;
  const _FilterBar({required this.selected, required this.total, required this.counts, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final opts = <(String, String, int, Color)>[
      ('All', 'all', total, AppColors.primary),
      ('Overdue', 'overdue', counts['overdue']!, AppColors.danger),
      ('Today', 'today', counts['today']!, AppColors.primary),
      ('This week', 'week', counts['week']!, const Color(0xFFF59E0B)),
      ('Later', 'later', counts['later']!, AppColors.textMuted),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        itemCount: opts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, value, count, accent) = opts[i];
          final on = value == selected;
          return GestureDetector(
            onTap: () => onSelect(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? accent : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? Colors.transparent : AppColors.border),
                boxShadow: on ? [BoxShadow(color: accent.withValues(alpha: 0.30), blurRadius: 6, offset: const Offset(0, 2))] : null,
              ),
              child: Row(children: [
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.textSecondary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: 0.25) : AppColors.background, borderRadius: BorderRadius.circular(10)),
                  child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: on ? Colors.white : AppColors.textMuted)),
                ),
              ]),
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
    final bucket = _bucketOf(v);
    final accent = _accentOf(bucket);
    final (relLabel, relColor) = _relative(v);
    final phone = v.customer?.phone;
    final d = v.scheduledDate;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dateBadge(d, accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.customer?.name ?? 'AMC visit', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text('${v.contractNumber ?? 'AMC'} · Visit #${v.sequence}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: relColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(bucket == _Bucket.overdue ? Icons.warning_amber_rounded : Icons.schedule, size: 13, color: relColor),
                  const SizedBox(width: 4),
                  Text(relLabel, style: TextStyle(color: relColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ]),
        const Divider(height: 22, color: AppColors.divider),
        Row(children: [
          if (phone != null && phone.isNotEmpty) ...[
            _pillBtn(Icons.call, 'Call', AppColors.textSecondary, false, () => _call(phone)),
            const SizedBox(width: 8),
          ],
          _pillBtn(Icons.directions, 'Navigate', AppColors.textSecondary, false, () => _navigate(v.customer?.name ?? '')),
          const Spacer(),
          _pillBtn(Icons.check_circle_outline, 'Done', AppColors.success, true, _busy ? null : _markDone, busy: _busy),
        ]),
      ]),
    );
  }

  Widget _dateBadge(DateTime? d, Color accent) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(d != null ? '${d.day}' : '—', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: accent, height: 1)),
        const SizedBox(height: 2),
        Text(d != null ? _months[d.month] : '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent.withValues(alpha: 0.85))),
      ]),
    );
  }

  /// Plain tappable pill — avoids Material button intrinsic-sizing quirks in list rows.
  /// `filled` = solid accent (primary action); otherwise an outlined neutral pill.
  Widget _pillBtn(IconData icon, String label, Color color, bool filled, VoidCallback? onTap, {bool busy = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: filled ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: filled ? color : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (busy)
            const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            Icon(icon, size: 16, color: filled ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: filled ? Colors.white : color)),
        ]),
      ),
    );
  }
}

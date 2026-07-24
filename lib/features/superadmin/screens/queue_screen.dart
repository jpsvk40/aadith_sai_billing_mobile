import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/platform_dashboard_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/sa_kit.dart';

/// Darken an accent a touch so it stays legible on white / on its own tint.
Color _shade(Color c) => Color.lerp(c, Colors.black, 0.28)!;

/// The platform Action Queue — every company awaiting a super-admin decision,
/// grouped by the kind of decision (approvals, trials, renewals, resets).
/// Each row (and its trailing action button) deep-links to the company detail
/// sheet, which hosts the real one-tap lifecycle actions.
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(platformDashboardProvider);
    final dash = async.valueOrNull;
    final total = dash == null ? null : _totalCount(dash);

    return Scaffold(
      backgroundColor: saBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(total),
            Expanded(
              child: async.when(
                loading: () => const LoadingIndicator(message: 'Loading queue…'),
                error: (e, _) => ErrorStateWidget(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(platformDashboardProvider),
                ),
                data: (data) => RefreshIndicator(
                  onRefresh: () async => ref.invalidate(platformDashboardProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      _group(
                        context,
                        'Pending approval',
                        saAmber,
                        _pending(data),
                        'Approve',
                        (c) => 'signed up ${saRelativeDays(c.createdAt)}',
                      ),
                      _group(
                        context,
                        'Trials expiring',
                        saSky,
                        data.expiringTrials,
                        'Extend',
                        (c) => 'ends ${saRelativeDays(c.trialEndsAt)}',
                      ),
                      _group(
                        context,
                        'Subscription renewals',
                        saEmerald,
                        data.expiringSubscriptions,
                        'Activate',
                        (c) => 'renews ${saRelativeDays(c.subscriptionEndsAt)}',
                      ),
                      _group(
                        context,
                        'Password resets',
                        saRose,
                        _resets(data),
                        'Unlock',
                        (_) => 'admin locked out',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Data slices ───────────────────────────────────────────────────────────

  List<PlatformCompanyCard> _pending(PlatformDashboard d) =>
      d.actionQueue.where((c) => c.status == 'pending_review').toList();

  List<PlatformCompanyCard> _resets(PlatformDashboard d) =>
      d.actionQueue.where((c) => c.mustChangePassword).toList();

  int _totalCount(PlatformDashboard d) =>
      _pending(d).length +
      d.expiringTrials.length +
      d.expiringSubscriptions.length +
      _resets(d).length;

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _header(int? total) {
    final String sub;
    if (total == null) {
      sub = 'Companies awaiting a decision';
    } else if (total == 0) {
      sub = "You're all caught up 🎉";
    } else {
      sub = '$total ${total == 1 ? 'company needs' : 'companies need'} a decision';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Action Queue',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: saInk, letterSpacing: -0.3),
          ),
          const SizedBox(height: 3),
          Text(sub, style: const TextStyle(fontSize: 13, color: saSlate, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── Group (header + card) ──────────────────────────────────────────────────

  Widget _group(
    BuildContext context,
    String title,
    Color color,
    List<PlatformCompanyCard> items,
    String actionLabel,
    String Function(PlatformCompanyCard) subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupHeader(title, items.length, color),
        SaCard(
          padding: EdgeInsets.zero,
          child: items.isEmpty
              ? _allClear()
              : Column(children: _rows(context, items, color, actionLabel, subtitle)),
        ),
      ],
    );
  }

  Widget _groupHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: saInk)),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text('$count',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _allClear() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Text('All clear 🎉',
            style: TextStyle(fontSize: 13, color: saMuted, fontWeight: FontWeight.w600)),
      );

  // ─── Rows ────────────────────────────────────────────────────────────────────

  List<Widget> _rows(
    BuildContext context,
    List<PlatformCompanyCard> items,
    Color color,
    String actionLabel,
    String Function(PlatformCompanyCard) subtitle,
  ) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const Divider(height: 1, thickness: 0.5, color: saLine));
      out.add(_row(context, items[i], color, subtitle(items[i]), actionLabel));
    }
    return out;
  }

  Widget _row(
    BuildContext context,
    PlatformCompanyCard item,
    Color color,
    String subtitle,
    String actionLabel,
  ) {
    void open() => context.push('/superadmin/companies/${item.id}');
    return InkWell(
      onTap: open,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left colour stripe keyed to the group.
            Container(width: 3, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 12, 12, 12),
                child: Row(
                  children: [
                    SaLogo(item.name, size: 40),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: saInk),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: saMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: open,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _shade(color),
                        backgroundColor: color.withValues(alpha: 0.08),
                        side: BorderSide(color: color.withValues(alpha: 0.45)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      child: Text(actionLabel),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

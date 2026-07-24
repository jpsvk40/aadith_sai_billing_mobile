import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/platform_dashboard_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/sa_kit.dart';

/// ───────────────────────────────────────────────────────────────────────────
/// Super Admin — Platform Control Tower.
///
/// The mobile "mission control" home for the platform operator: a dark hero
/// with a live alert strip, platform KPIs, a company status/market mix, and the
/// decisions / registrations / activity that matter right now. Sits inside the
/// [SuperAdminShell] (which owns the Scaffold + four-tab bottom nav), so this
/// screen returns the scrollable body directly.
/// ───────────────────────────────────────────────────────────────────────────
class ControlTowerScreen extends ConsumerWidget {
  const ControlTowerScreen({super.key});

  // Bright on-navy accents for the hero alert numbers (readable on the gradient).
  static const _kicker = Color(0xFF9DB2FF);
  static const _amberLite = Color(0xFFFCD34D);
  static const _skyLite = Color(0xFF7DD3FC);
  static const _emeraldLite = Color(0xFF86EFAC);
  static const _roseLite = Color(0xFFFCA5A5);

  // Ordered status vocabulary for the mix bar + legend (skips zero counts).
  static const _statusOrder = [
    'active',
    'trial_active',
    'pending_review',
    'trial_expired',
    'suspended',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(platformDashboardProvider);
    final user = ref.watch(authProvider).user;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorState(ref),
      data: (dash) => RefreshIndicator(
        color: saIndigo,
        onRefresh: () async => ref.invalidate(platformDashboardProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _hero(context, dash.totals, user?.name ?? 'Super Admin'),
            _body(context, dash),
          ],
        ),
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────────
  Widget _errorState(WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: saMuted),
            const SizedBox(height: 14),
            const Text('Could not load the Control Tower',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: saInk)),
            const SizedBox(height: 6),
            const Text('Check your connection and try again.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: saMuted)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(platformDashboardProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: saIndigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mission-control hero ─────────────────────────────────────────────────────
  Widget _hero(BuildContext context, PlatformTotals t, String name) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        decoration: const BoxDecoration(gradient: saHeroGradient),
        child: Stack(
          children: [
            Positioned(top: -60, right: -40, child: _glow(200, saIndigo.withValues(alpha: 0.28))),
            Positioned(bottom: -50, left: -30, child: _glow(170, saSky.withValues(alpha: 0.16))),
            Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PLATFORM CONTROL TOWER',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                    color: _kicker)),
                            const SizedBox(height: 8),
                            Text('${_greeting()} 👋',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
                            const SizedBox(height: 2),
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.15)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                              ),
                              child: const Text('⚡ Super Admin · Platform',
                                  style: TextStyle(
                                      fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.tune, color: Colors.white, size: 20),
                          onPressed: () => context.go('/superadmin/settings'),
                          tooltip: 'Platform settings',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _alert(context, t.pendingReview, 'Pending approval', _amberLite),
                        const SizedBox(width: 9),
                        _alert(context, t.trialsExpiringSoon, 'Trials ending ≤7d', _skyLite),
                        const SizedBox(width: 9),
                        _alert(context, t.subscriptionsExpiringSoon, 'Renewals ≤14d', _emeraldLite),
                        const SizedBox(width: 9),
                        _alert(context, t.passwordResetRequired, 'Password resets', _roseLite),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double d, Color c) =>
      Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _alert(BuildContext context, int value, String caption, Color numberColor) {
    return GestureDetector(
      onTap: () => context.go('/superadmin/queue'),
      child: Container(
        width: 128,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -0.5,
                    color: numberColor)),
            const SizedBox(height: 6),
            Text(caption,
                style: TextStyle(
                    fontSize: 10.5, height: 1.25, color: Colors.white.withValues(alpha: 0.62))),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ── Body sheet ───────────────────────────────────────────────────────────────
  Widget _body(BuildContext context, PlatformDashboard d) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: Container(
        decoration: const BoxDecoration(
          color: saBg,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SaSectionHeader('Platform at a glance'),
            _glanceGrid(d.totals),
            const SizedBox(height: 12),
            _mrrCard(),
            const SizedBox(height: 22),
            const SaSectionHeader('Company status mix'),
            _statusMix(d.statusBreakdown, d.marketBreakdown),
            const SizedBox(height: 22),
            SaSectionHeader('Needs your decision',
                actionLabel: 'See all ›', onAction: () => context.go('/superadmin/queue')),
            _decisionList(context, d.actionQueue),
            const SizedBox(height: 22),
            const SaSectionHeader('Recent registrations'),
            _registrationsList(context, d.recentRegistrations),
            const SizedBox(height: 22),
            const SaSectionHeader('Recent platform activity'),
            _activityCard(d.latestActivity),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Platform at a glance ─────────────────────────────────────────────────────
  Widget _glanceGrid(PlatformTotals t) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 11,
      crossAxisSpacing: 11,
      childAspectRatio: 2.2,
      children: [
        _kpiTile(t.totalCompanies, 'Companies', Icons.business_outlined, saBlue),
        _kpiTile(t.activeSubscriptions, 'Active subs', Icons.verified_outlined, saEmerald),
        _kpiTile(t.trialActive, 'On trial', Icons.hourglass_bottom, saAmber),
        _kpiTile(t.totalUsers, 'Total users', Icons.groups_outlined, saIndigo),
      ],
    );
  }

  Widget _kpiTile(int value, String label, IconData icon, Color color) {
    return SaCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800, height: 1, color: saInk)),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: saSlate)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mrrCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [saBlue, saIndigoDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: saIndigoDark.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.credit_card, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Platform fee · MRR',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85))),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('PROPOSED',
                          style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('—',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text('Wire up in Platform → Fees',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.72))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Company status mix ───────────────────────────────────────────────────────
  Widget _statusMix(Map<String, int> status, Map<String, int> market) {
    final entries = [
      for (final k in _statusOrder)
        if ((status[k] ?? 0) > 0) MapEntry(k, status[k]!),
    ];
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    int mkt(String k) => market[k] ?? 0;
    final marketLine = '🇮🇳 ${mkt('india')} · 🇺🇸 ${mkt('us')} · 🌐 ${mkt('other')}';

    return SaCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? Container(color: saLine)
                  : Row(
                      children: [
                        for (final e in entries)
                          Expanded(flex: e.value, child: Container(color: saStatusColor(e.key))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Text('No companies yet.', style: TextStyle(fontSize: 12.5, color: saMuted))
          else
            ..._legendRows(entries),
          const SizedBox(height: 10),
          const Divider(height: 1, color: saLine),
          const SizedBox(height: 10),
          Text(marketLine,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: saSlate)),
        ],
      ),
    );
  }

  /// Two-per-row legend (dot + label + count), built from the ordered entries.
  List<Widget> _legendRows(List<MapEntry<String, int>> entries) {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 2) {
      final left = entries[i];
      final right = i + 1 < entries.length ? entries[i + 1] : null;
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + 2 < entries.length ? 8 : 0),
        child: Row(
          children: [
            Expanded(child: _legendCell(left)),
            const SizedBox(width: 14),
            Expanded(child: right == null ? const SizedBox.shrink() : _legendCell(right)),
          ],
        ),
      ));
    }
    return rows;
  }

  Widget _legendCell(MapEntry<String, int> e) {
    final color = saStatusColor(e.key);
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(saStatusLabel(e.key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: saSlate)),
        ),
        Text('${e.value}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: saInk)),
      ],
    );
  }

  // ── Needs your decision ──────────────────────────────────────────────────────
  Widget _decisionList(BuildContext context, List<PlatformCompanyCard> queue) {
    if (queue.isEmpty) {
      return const SaCard(
        child: Text('All clear — nothing needs a decision 🎉',
            style: TextStyle(fontSize: 13, color: saMuted)),
      );
    }
    final items = queue.take(3).toList();
    return SaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _companyRow(
              context,
              items[i],
              subtitle: items[i].actionLabel ?? saRelativeDays(items[i].deadline),
              trailing: SaStatusPill(items[i].status),
              showDivider: i != items.length - 1,
            ),
        ],
      ),
    );
  }

  // ── Recent registrations ─────────────────────────────────────────────────────
  Widget _registrationsList(BuildContext context, List<PlatformCompanyCard> recent) {
    if (recent.isEmpty) {
      return const SaCard(
        child: Text('No registrations yet.', style: TextStyle(fontSize: 13, color: saMuted)),
      );
    }
    final items = recent.take(3).toList();
    return SaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _companyRow(
              context,
              items[i],
              subtitle: items[i].primaryAdminEmail.isEmpty ? '—' : items[i].primaryAdminEmail,
              trailing: SaStatusPill(items[i].status),
              showDivider: i != items.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _companyRow(
    BuildContext context,
    PlatformCompanyCard c, {
    required String subtitle,
    required Widget trailing,
    required bool showDivider,
  }) {
    return InkWell(
      onTap: () => context.push('/superadmin/companies/${c.id}'),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: showDivider ? saLine : Colors.transparent, width: 1),
          ),
        ),
        child: Row(
          children: [
            SaLogo(c.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name.isEmpty ? '—' : c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700, color: saInk)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: saMuted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }

  // ── Recent platform activity ─────────────────────────────────────────────────
  Widget _activityCard(List<PlatformActivity> activity) {
    if (activity.isEmpty) {
      return const SaCard(
        child: Text('No recent activity yet.', style: TextStyle(fontSize: 13, color: saMuted)),
      );
    }
    final items = activity.take(6).toList();
    return SaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _activityRow(items[i], showDivider: i != items.length - 1),
        ],
      ),
    );
  }

  Widget _activityRow(PlatformActivity a, {required bool showDivider}) {
    final (icon, color) = _activityIcon(a.action);
    final where = (a.companyName == null || a.companyName!.isEmpty) ? '—' : a.companyName!;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: showDivider ? saLine : Colors.transparent, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text('${a.prettyAction} · $where',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: saInk)),
          ),
          const SizedBox(width: 8),
          Text(saRelativeDays(a.createdAt),
              style: const TextStyle(fontSize: 11, color: saMuted)),
        ],
      ),
    );
  }

  (IconData, Color) _activityIcon(String action) {
    final a = action.toLowerCase();
    if (a.contains('approve')) return (Icons.check_circle_outline, saEmerald);
    if (a.contains('password') || a.contains('reset') || a.contains('unlock')) {
      return (Icons.lock_reset, saRose);
    }
    if (a.contains('extend') || a.contains('trial')) return (Icons.schedule, saSky);
    if (a.contains('activate') || a.contains('subscription')) {
      return (Icons.verified_outlined, saBlue);
    }
    if (a.contains('suspend')) return (Icons.pause_circle_outline, saAmber);
    if (a.contains('delete') || a.contains('cancel')) return (Icons.delete_outline, saRose);
    return (Icons.bolt_outlined, saIndigo);
  }
}

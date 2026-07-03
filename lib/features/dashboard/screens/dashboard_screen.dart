import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/mobile_home_model.dart';
import '../../../data/models/command_center_model.dart';
import '../../service/providers/service_providers.dart';
import '../providers/home_provider.dart';
import '../providers/command_center_provider.dart';
import '../widgets/command_center_view.dart';

// SkillTrackr-style palette
const _heroA = Color(0xFF0369A1);
const _heroB = Color(0xFF1D4ED8);
const _heroC = Color(0xFF1E1B4B);
const _purple = Color(0xFF7C3AED);
const _orange = Color(0xFFF59E0B);
const _statBlue = Color(0xFF60A5FA);
const _statPurple = Color(0xFFA78BFA);
const _statGreen = Color(0xFF4ADE80);
const _statGold = Color(0xFFFBBF24);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeProvider.notifier).load();
      final mods = ref.read(authProvider).user?.effectiveModules ?? const [];
      ref.read(commandCenterProvider.notifier).load(modules: mods.toSet());
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _soon(String w) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$w — coming in the next update')));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final user = ref.watch(authProvider).user;
    final isService = user?.hasModule('warranty_service') == true;
    // Open-ticket count for the hero (only when this is a service company).
    final openTickets = isService
        ? (ref.watch(serviceDashboardProvider).valueOrNull?['kpis']?['openTotal'] as int?)
        : null;
    final o = state.overview ?? const HomeOverview();
    // ERP companies (construction modules) get the lens-based command center home
    // instead of the billing hero/P&L — no billing KPIs, useful for admins.
    final isErp = user?.hasModule('projects') == true ||
        user?.hasModule('machinery') == true ||
        user?.hasModule('tender') == true;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: state.isLoading && state.overview == null
          ? const LoadingIndicator(message: 'Loading your overview...')
          : state.error != null && state.overview == null
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(homeProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(homeProvider.notifier).load();
                    final mods = ref.read(authProvider).user?.effectiveModules ?? const [];
                    await ref.read(commandCenterProvider.notifier).load(modules: mods.toSet());
                  },
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      o.isRep ? _repHero(context, o, user) : _hero(context, o, user, openTickets, isErp),
                      _sheet(o.isRep ? _repBody(context, o, user) : _ownerBody(o, user)),
                    ],
                  ),
                ),
    );
  }

  Widget _sheet(Widget child) => Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26))),
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: child,
        ),
      );

  Widget _ownerBody(HomeOverview o, dynamic user) {
    // Service companies get a dedicated, service-only Home (no billing P&L / payroll / cash-flow noise).
    if (user?.hasModule('warranty_service') == true) return _serviceOwnerBody();

    // ERP companies (construction) get the lens-based command center — no billing KPIs.
    final isErp = user?.hasModule('projects') == true ||
        user?.hasModule('machinery') == true ||
        user?.hasModule('tender') == true;
    if (isErp) {
      return Column(
        children: [
          const CommandCenterView(),
          const SizedBox(height: 20),
          _quickAccess(),
          const SizedBox(height: 20),
          _recentActivity(o),
          const SizedBox(height: 16),
        ],
      );
    }

    final hasOrders = user?.hasModule('orders') == true;
    final cc = ref.watch(commandCenterProvider);
    final ac = cc.action;
    final mb = cc.money;
    return Column(
      children: [
        // ── Executive Command Center (mirrors the web Command Center) ──
        if (ac != null && ac.totalItems > 0) ...[
          _attentionHeader(ac),
          const SizedBox(height: 14),
        ],
        if (mb != null) ...[
          _execKpis(mb),
          const SizedBox(height: 20),
        ],
        // Payment approvals waiting on the owner.
        if (o.pendingApprovals > 0) ...[
          _actionQueueBanner(o),
          const SizedBox(height: 20),
        ],
        if (ac != null && ac.items.isNotEmpty) ...[
          _actionCenter(ac),
          const SizedBox(height: 20),
        ],
        _quickAccess(),
        const SizedBox(height: 20),
        _plCard(o),
        const SizedBox(height: 20),
        // Orders-by-status only makes sense for companies that run the orders module.
        if (hasOrders) ...[
          _ordersByStatus(o),
          const SizedBox(height: 20),
        ],
        _outstandingAndCash(o),
        const SizedBox(height: 20),
        // Money map — the payables side (what the owner owes vendors).
        if (o.payablesOutstanding > 0) ...[
          _payablesCard(o),
          const SizedBox(height: 20),
        ],
        _recentActivity(o),
        const SizedBox(height: 16),
      ],
    );
  }

  // ---------------- Owner action queue (Approvals) ----------------
  Widget _actionQueueBanner(HomeOverview o) {
    return GestureDetector(
      onTap: () => context.go('/approvals'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_orange, Color(0xFFD97706)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _orange.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${o.pendingApprovals} awaiting your approval',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text('Payments, orders & vouchers need a decision', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ════════════ Executive Command Center ════════════
  Widget _attentionHeader(ActionCenter ac) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _orange.withValues(alpha: 0.30)),
      ),
      child: Row(children: [
        const Icon(Icons.bolt, color: _orange, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              children: [
                TextSpan(text: '${ac.totalItems} item${ac.totalItems == 1 ? '' : 's'} need attention'),
                if (ac.urgent > 0) TextSpan(text: '  ·  ${ac.urgent} urgent', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                if (ac.amountAtRisk > 0) TextSpan(text: '  ·  ${CurrencyUtils.formatCompact(ac.amountAtRisk)} at risk', style: const TextStyle(color: _orange, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _execKpis(MoneyBand mb) {
    String money(double? v) => v == null ? '—' : CurrencyUtils.formatCompact(v);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _kpiCard('Cash on hand', money(mb.cashOnHand), Icons.account_balance_wallet_outlined, AppColors.primary),
        _kpiCard('Overdue AR', money(mb.overdueAR), Icons.schedule_outlined,
            (mb.overdueAR ?? 0) > 0 ? AppColors.danger : AppColors.success,
            sub: mb.overdueARCount > 0 ? '${mb.overdueARCount} invoices' : null),
        _kpiCard('Payables', money(mb.payables), Icons.account_balance_outlined, _orange,
            sub: mb.payablesCount > 0 ? '${mb.payablesCount} bills' : null),
        _kpiCard('Margin', mb.marginPct == null ? '—' : '${mb.marginPct}%', Icons.trending_up, AppColors.success),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color, {String? sub}) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _actionCenter(ActionCenter ac) {
    Color sevColor(String s) => s == 'high' ? AppColors.danger : (s == 'medium' ? _orange : AppColors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Action Center', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        _card(
          child: Column(
            children: List.generate(ac.items.length, (i) {
              final it = ac.items[i];
              final last = i == ac.items.length - 1;
              final c = sevColor(it.severity);
              return InkWell(
                onTap: () => _openAction(it.actionUrl),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.divider, width: 0.6))),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text(it.module, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          if (it.amountAtRisk > 0) Text('  ·  ${CurrencyUtils.formatCompact(it.amountAtRisk)}', style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
                          if (it.dueInDays != null)
                            Text('  ·  ${it.dueInDays! < 0 ? '${-it.dueInDays!}d overdue' : (it.dueInDays == 0 ? 'due today' : 'in ${it.dueInDays}d')}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ]),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
                      child: Text('${it.count}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // Map a web action route to the closest mobile screen; nudge to the web otherwise.
  void _openAction(String? url) {
    if (url == null) return;
    const map = {
      '/reports/outstanding': '/reports',
      '/vendor-payments': '/purchases',
      '/procurement': '/purchases',
      '/site-logistics': '/site-logistics',
    };
    final target = map[url];
    if (target != null) {
      context.go(target);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manage this in the web portal for now')));
    }
  }

  // ---------------- Payables (money owed to vendors) ----------------
  Widget _payablesCard(HomeOverview o) {
    return GestureDetector(
      onTap: () => context.go('/purchases'),
      child: _card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_outlined, color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Payable to Vendors', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(CurrencyUtils.format(o.payablesOutstanding), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ]),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  // ════════════ Service-only owner Home ════════════
  Widget _serviceOwnerBody() {
    return Column(
      children: [
        _serviceSnapshot(),
        const SizedBox(height: 20),
        _quickAccess(),
        const SizedBox(height: 20),
        _serviceDataSection(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _serviceDataSection() {
    final async = ref.watch(serviceDashboardProvider);
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => const SizedBox.shrink(),
      data: (d) {
        final rev = (d['revenueThisMonth'] as Map<String, dynamic>?) ?? const {};
        final k = (d['kpis'] as Map<String, dynamic>?) ?? const {};
        final exp = (k['warrantiesExpiring'] as Map<String, dynamic>?) ?? const {};
        final recent = (d['recentTickets'] as List<dynamic>?) ?? const [];
        final expTotal = ((exp['d30'] ?? 0) as num) + ((exp['d60'] ?? 0) as num) + ((exp['d90'] ?? 0) as num);
        return Column(
          children: [
            // Service revenue this month (labour + parts), what's collected, what's owed.
            _card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionHeader('Service Revenue · This Month', 'Reports', () => context.go('/service/reports')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _miniStat('Billed', CurrencyUtils.format(rev['billed'] ?? 0), AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: _miniStat('Collected', CurrencyUtils.format(rev['collected'] ?? 0), AppColors.success)),
                  const SizedBox(width: 12),
                  Expanded(child: _miniStat('Receivable', CurrencyUtils.format(k['outstandingReceivables'] ?? 0), _orange)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _svcInline('Labour', CurrencyUtils.format(rev['labour'] ?? 0))),
                  Expanded(child: _svcInline('Parts', CurrencyUtils.format(rev['parts'] ?? 0))),
                ]),
              ]),
            )),
            const SizedBox(height: 16),
            // Operations at a glance.
            _card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Operations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _opStat('${k['intakeToday'] ?? 0}', 'Intake today', AppColors.primary)),
                  Expanded(child: _opStat('${k['deliveredToday'] ?? 0}', 'Delivered today', AppColors.success)),
                  Expanded(child: _opStat('${(k['avgTurnaroundDays'] ?? 0)}', 'Avg TAT (days)', _purple)),
                ]),
              ]),
            )),
            if (expTotal > 0) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.go('/service/items'),
                child: _card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.verified_user_outlined, color: _orange),
                    const SizedBox(width: 12),
                    Expanded(child: Text('$expTotal warranties expiring soon', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    Text('30d ${exp['d30'] ?? 0} · 60d ${exp['d60'] ?? 0} · 90d ${exp['d90'] ?? 0}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                  ]),
                )),
              ),
            ],
            const SizedBox(height: 16),
            _recentTickets(recent),
          ],
        );
      },
    );
  }

  Widget _recentTickets(List<dynamic> recent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Tickets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          _card(child: const Padding(padding: EdgeInsets.all(16), child: Text('No recent tickets.', style: TextStyle(color: AppColors.textSecondary))))
        else
          _card(child: Column(
            children: List.generate(recent.length.clamp(0, 6), (i) {
              final r = recent[i] as Map<String, dynamic>;
              final last = i == recent.length.clamp(0, 6) - 1;
              final cust = (r['customer'] as Map<String, dynamic>?)?['customerName']?.toString() ?? '—';
              final status = (r['status'] ?? 'OPEN').toString();
              return InkWell(
                onTap: () => context.go('/service/tickets/${r['id']}'),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.divider, width: 0.6))),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.build_outlined, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r['ticketNumber'] ?? ''}  ·  $cust', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                      Text(status, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    if (r['totalCharge'] != null)
                      Text(CurrencyUtils.formatCompact(r['totalCharge']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                  ]),
                ),
              );
            }),
          )),
      ],
    );
  }

  Widget _svcInline(String label, String value) => Row(children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]);

  Widget _opStat(String value, String label, Color color) => Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]);

  // ---------------- Service snapshot (owner of a service company) ----------------
  Widget _serviceSnapshot() {
    final async = ref.watch(serviceDashboardProvider);
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Service Overview', 'Open', () => context.go('/service/dashboard')),
            const SizedBox(height: 14),
            async.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))),
              error: (e, _) => const Text('Could not load service stats', style: TextStyle(color: AppColors.textSecondary)),
              data: (d) {
                final k = (d['kpis'] as Map<String, dynamic>?) ?? const {};
                return Row(children: [
                  _svcStat('Open', '${k['openTotal'] ?? 0}', AppColors.primary),
                  _svcStat('Unassigned', '${k['unassigned'] ?? 0}', _orange),
                  _svcStat('Ready', '${k['readyForDelivery'] ?? 0}', AppColors.success),
                  _svcStat('SLA', '${k['slaBreached'] ?? 0}', AppColors.danger),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _svcStat(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );

  // ---------------- Rep Home ----------------
  Widget _repHero(BuildContext context, HomeOverview o, dynamic user) {
    final String name = (o.repName ?? user?.name ?? 'Welcome').toString();
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    final stats = _repStats(o);
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_heroA, _heroB, _heroC], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: _circle(200, Colors.white.withValues(alpha: 0.05))),
            Positioned(bottom: -30, left: -20, child: _circle(160, const Color(0xFF6366F1).withValues(alpha: 0.12))),
            Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${_greeting()} 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text("Here's your day", style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                      ]),
                    ),
                    _bell(context),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      width: 56, height: 56, alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2)),
                      child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                          child: Text(_repRoleLabel(o), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _heroStat(stats[i].$1, stats[i].$2, stats[i].$3),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _repRoleLabel(HomeOverview o) {
    if (o.repCanSell && o.repCanCollect) return '🧑‍💼 Sales & Collection';
    if (o.repCanCollect) return '💰 Collection Rep';
    return '🧑‍💼 Sales Rep';
  }

  List<(String, String, Color)> _repStats(HomeOverview o) {
    final list = <(String, String, Color)>[];
    if (o.repCanSell) {
      list.add((CurrencyUtils.formatCompact(o.repSales), 'Sales', _statBlue));
      list.add(('${o.repOrders}', 'Orders', _statPurple));
    }
    if (o.repCanCollect) {
      list.add((CurrencyUtils.formatCompact(o.repCollected), 'Collected', _statGreen));
      list.add((CurrencyUtils.formatCompact(o.repToCollect), 'To Collect', _statGold));
    }
    if (o.repCanSell && !o.repCanCollect) {
      list.add(('${o.repCustomers}', 'Customers', _statGreen));
      list.add((CurrencyUtils.formatCompact(o.repCommissionPending), 'Commission', _statGold));
    }
    return list.take(4).toList();
  }

  Widget _repBody(BuildContext context, HomeOverview o, dynamic user) {
    // Only surface quick links for modules this rep actually has access to.
    bool has(String m) => user?.hasModule(m) == true;
    final actions = <(IconData, String, Color, VoidCallback)>[];
    if (has('orders')) {
      actions.add((Icons.add_circle_outline, 'New Order', AppColors.primary, () => context.push('/orders/create')));
      actions.add((Icons.receipt_long, 'My Orders', _purple, () => context.go('/orders')));
    }
    if (has('customers')) {
      actions.add((Icons.people_outline, 'Customers', AppColors.success, () => context.go('/customers')));
    }
    if (has('collections')) {
      actions.add((Icons.account_balance_wallet_outlined, 'Collections', const Color(0xFF0891B2), () => context.go('/collections')));
    }
    if (has('invoices')) {
      actions.add((Icons.schedule, 'Outstanding', AppColors.danger, () => context.go('/invoices?filter=Unpaid')));
      actions.add((Icons.description_outlined, 'Invoices', const Color(0xFF6366F1), () => context.go('/invoices')));
    }
    if (has('reports')) {
      actions.add((Icons.percent, 'Commission', _orange, () => context.go('/commissions')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (o.repCanCollect && o.repPendingAssignments > 0) ...[
          _attnBanner('${o.repPendingAssignments} collection${o.repPendingAssignments > 1 ? 's' : ''} pending', () => context.go('/collections')),
          const SizedBox(height: 20),
        ],
        const Text('Quick Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.92,
          children: actions.map((a) => _qaTile(a.$1, a.$2, a.$3, a.$4)).toList(),
        ),
        if (has('reports')) ...[
          const SizedBox(height: 20),
          _repCommissionCard(context, o),
        ],
        const SizedBox(height: 20),
        _recentActivity(o),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _attnBanner(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.warning.withValues(alpha: 0.4))),
        child: Row(children: [
          const Icon(Icons.priority_high_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _repCommissionCard(BuildContext context, HomeOverview o) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader('My Commission', 'View', () => context.go('/commissions')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _miniStat('This Month', CurrencyUtils.format(o.repCommissionMonth), AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _miniStat('Pending', CurrencyUtils.format(o.repCommissionPending), _orange)),
          ]),
        ]),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _qaTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.18)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 9),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color.lerp(color, Colors.black, 0.45))),
        ]),
      ),
    );
  }

  // ---------------- Hero ----------------
  Widget _hero(BuildContext context, HomeOverview o, dynamic user, int? openTickets, [bool isErp = false]) {
    final companyName = o.companyName ?? user?.companyName ?? 'Your Business';
    final isService = openTickets != null;
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_heroA, _heroB, _heroC], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: _circle(200, Colors.white.withValues(alpha: 0.05))),
            Positioned(bottom: -30, left: -20, child: _circle(160, const Color(0xFF6366F1).withValues(alpha: 0.12))),
            Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // greeting + bell
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_greeting()} 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text("Here's your business snapshot", style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                          ],
                        ),
                      ),
                      _bell(context),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // identity row
                  Row(
                    children: [
                      _logoBox(o.companyLogo),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(companyName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15)),
                            if (user?.name != null)
                              Text(user!.name!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                  child: Text('👑 ${_roleLabel(o.role)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                                // Billing P&L chip is noise for ERP admins — hide it there.
                                if (!isErp) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.trending_up, size: 13, color: o.plNet >= 0 ? _statGold : AppColors.danger),
                                  const SizedBox(width: 3),
                                  Text('${CurrencyUtils.formatCompact(o.plNet)} net',
                                      style: TextStyle(color: o.plNet >= 0 ? _statGold : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w800)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Billing stat strip + attention chip — only for billing companies.
                  // ERP admins get the command-center attention header + money band below.
                  if (!isErp) ...[
                    const SizedBox(height: 20),
                    // glassy stat strip
                    Row(
                      children: [
                        _heroStat(CurrencyUtils.formatCompact(o.revenueThisMonth), 'Revenue', _statBlue),
                        const SizedBox(width: 8),
                        _heroStat(CurrencyUtils.formatCompact(o.collectedThisMonth), 'Collected', _statGreen),
                        const SizedBox(width: 8),
                        // Service companies have no orders — surface open tickets instead.
                        isService
                            ? _heroStat('$openTickets', 'Open Jobs', _statPurple)
                            : _heroStat('${o.ordersThisMonth}', 'Orders', _statPurple),
                        const SizedBox(width: 8),
                        _heroStat(CurrencyUtils.formatCompact(o.receivablesOutstanding), 'Outstanding', _statGold),
                      ],
                    ),
                    // attention chip
                    if (o.pendingApprovals > 0 || o.overdueInvoices > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            if (o.pendingApprovals > 0)
                              Expanded(child: _attnSegment(Icons.fact_check_outlined, '${o.pendingApprovals} to approve', () => context.go('/approvals'))),
                            if (o.pendingApprovals > 0 && o.overdueInvoices > 0)
                              Container(width: 1, height: 22, color: Colors.white.withValues(alpha: 0.25)),
                            if (o.overdueInvoices > 0)
                              Expanded(child: _attnSegment(Icons.schedule, '${o.overdueInvoices} overdue', () => context.go('/invoices?filter=Overdue'))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double d, Color c) =>
      Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _attnSegment(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right, size: 15, color: Colors.white.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String? role) {
    if (role == null) return 'Admin';
    final r = role.toLowerCase();
    if (r.contains('admin') || r.contains('owner')) return 'Admin';
    if (r.contains('rep')) return 'Representative';
    return role;
  }

  Widget _bell(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
            onPressed: () => context.go('/alerts'),
          ),
        ),
        Positioned(
          top: 7, right: 7,
          child: Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, border: Border.all(color: _heroB, width: 1.5))),
        ),
      ],
    );
  }

  Widget _heroStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _logoBox(String? logo) {
    final fallback = Container(
      width: 78, height: 78,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3)),
      child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 34),
    );
    if (logo == null || logo.isEmpty) return fallback;
    try {
      final b64 = logo.contains(',') ? logo.split(',').last : logo;
      final bytes = base64Decode(b64);
      return Container(
        width: 78, height: 78, padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3)),
        child: ClipRRect(borderRadius: BorderRadius.circular(14),
            child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront_outlined, color: AppColors.primary))),
      );
    } catch (_) {
      return fallback;
    }
  }

  // ---------------- Quick Access ----------------
  Widget _quickAccess() {
    final user = ref.read(authProvider).user;
    bool has(String m) => user?.hasModule(m) == true;
    final isService = has('warranty_service');
    // Build module-relevant tiles. Service companies lead with service actions and drop
    // sales/procurement tiles that don't apply.
    final actions = <(IconData, String, Color, VoidCallback)>[
      if (isService) ...[
        (Icons.handyman_outlined, 'Service', _purple, () => context.go('/service/dashboard')),
        (Icons.add_circle_outline, 'New Ticket', AppColors.primary, () => context.go('/service/tickets/create')),
        (Icons.calendar_month_outlined, 'Calendar', const Color(0xFF0EA5E9), () => context.go('/service/calendar')),
        (Icons.qr_code_scanner, 'Warranty', const Color(0xFF0891B2), () => context.go('/service/warranty-lookup')),
        (Icons.event_available_outlined, 'AMC Today', _orange, () => context.go('/service/today')),
      ],
      if (!isService)
        (Icons.add_shopping_cart, 'New Purchase', AppColors.primary, () => context.go('/purchases')),
      if (has('orders'))
        (Icons.receipt_long, 'Orders', _purple, () => context.go('/orders')),
      // Site Logistics belongs to the Project & Contract (ERP) module — hide it for billing-only companies.
      if (has('projects'))
        (Icons.location_on_outlined, 'Site Logistics', const Color(0xFF0EA5E9), () => context.go('/site-logistics')),
      // Correspondence — letters awaiting reply are actionable on mobile.
      if (has('correspondence'))
        (Icons.mail_outline, 'Letters', const Color(0xFF0284C7), () => context.go('/correspondence')),
      // Payments moved off the ERP bottom nav — keep it reachable here.
      if (has('payments'))
        (Icons.payments_outlined, 'Payments', const Color(0xFF059669), () => context.go('/payments')),
      // Shared back-office spine — one tap to the Finance hub (GST / payables / GL / expenses / payroll).
      if (user?.hasSpine == true)
        (Icons.account_balance_outlined, 'Finance', const Color(0xFF6366F1), () => context.push('/finance')),
      if (has('customers'))
        (Icons.people_alt_outlined, 'Customers', const Color(0xFF1D4ED8), () => context.push('/customers')),
      (Icons.check_circle_outline, 'Approvals', _orange, () => context.go('/approvals')),
      if (has('invoices'))
        (Icons.description_outlined, 'Invoices', const Color(0xFF6366F1), () => context.go('/invoices')),
      if (has('collections'))
        (Icons.account_balance_wallet_outlined, 'Collections', const Color(0xFF0891B2), () => context.go('/collections')),
      // "Ask AI" lives in the always-on floating launcher now (see FloatingAssistantButton).
      if (has('reports'))
        (Icons.insights_outlined, 'Reports', AppColors.danger, () => isService ? context.go('/service/reports') : context.go('/reports')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: actions.map((a) {
            return InkWell(
              onTap: a.$4,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: a.$3,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [BoxShadow(color: a.$3.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Icon(a.$1, color: Colors.white, size: 25),
                    ),
                    const SizedBox(height: 10),
                    Text(a.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------- P&L card with donut ----------------
  Widget _plCard(HomeOverview o) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('This Month P&L', 'View Report', () => context.go('/reports')),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(width: 120, height: 120, child: _donut(o)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _plLine(Icons.account_balance_wallet, 'Revenue (Billed)', o.plIncome, AppColors.primary, AppColors.primary),
                      _plLine(Icons.shopping_cart_outlined, 'Vendor Purchases', o.plPurchases, AppColors.success, AppColors.danger),
                      _plLine(Icons.card_giftcard, 'Office Expenses', o.plExpenses, _orange, AppColors.danger),
                      _plLine(Icons.person_outline, 'Payroll', o.plPayroll, _purple, AppColors.danger),
                      const Divider(height: 16),
                      _plLine(Icons.savings_outlined, 'Net Profit', o.plNet, AppColors.success, o.plNet >= 0 ? AppColors.success : AppColors.danger, bold: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _donut(HomeOverview o) {
    final segs = <(double, Color)>[
      (o.plNet.abs(), AppColors.primary),
      (o.plPurchases, AppColors.danger),
      (o.plExpenses, _orange),
      (o.plPayroll, _purple),
    ].where((e) => e.$1 > 0).toList();
    return Stack(
      alignment: Alignment.center,
      children: [
        if (segs.isNotEmpty)
          PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: segs.map((e) => PieChartSectionData(value: e.$1, color: e.$2, radius: 16, showTitle: false)).toList(),
          )),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(CurrencyUtils.formatCompact(o.plNet), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const Text('Net Profit', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _plLine(IconData icon, String label, double value, Color iconColor, Color valueColor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: AppColors.textPrimary))),
          Text(CurrencyUtils.formatCompact(value), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  // ---------------- Orders by status ----------------
  Widget _ordersByStatus(HomeOverview o) {
    final items = [
      ('Total Orders', o.stTotal, AppColors.primary),
      ('In Production', o.stInProduction, _orange),
      ('Ready to Pack', o.stReadyToPack, _purple),
      ('Ready to Dispatch', o.stReadyToDispatch, AppColors.info),
      ('Delivered', o.stDelivered, AppColors.success),
    ];
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Orders by Status', 'View All', () => context.go('/orders')),
            const SizedBox(height: 14),
            Row(
              children: items.map((it) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        Text('${it.$2}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: it.$3)),
                        const SizedBox(height: 2),
                        Text(it.$1, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Container(height: 4, decoration: BoxDecoration(color: it.$3, borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Outstanding + Cash flow ----------------
  Widget _outstandingAndCash(HomeOverview o) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _outstandingCard(o)),
        const SizedBox(width: 12),
        Expanded(child: _cashCard(o)),
      ],
    );
  }

  Widget _outstandingCard(HomeOverview o) {
    final rows = [
      ('0-30 Days', o.aging0_30, AppColors.success),
      ('31-60 Days', o.aging31_60, _orange),
      ('61-90 Days', o.aging61_90, _purple),
      ('90+ Days', o.aging90, AppColors.danger),
    ];
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Outstanding', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: r.$3, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
                      Text(CurrencyUtils.formatCompact(r.$2), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: r.$3)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _cashCard(HomeOverview o) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cash Flow', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _cashRow(Icons.south, 'Cash Inflow', o.cashInflow, AppColors.success),
            const SizedBox(height: 12),
            _cashRow(Icons.north, 'Cash Outflow', o.cashOutflow, AppColors.danger),
            const Divider(height: 20),
            _cashRow(Icons.trending_up, 'Net Cash Flow', o.cashNet, o.cashNet >= 0 ? AppColors.primary : AppColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _cashRow(IconData icon, String label, double value, Color color) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(CurrencyUtils.formatCompact(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- Recent activity ----------------
  Widget _recentActivity(HomeOverview o) {
    if (o.recentActivity.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        _card(
          child: Column(
            children: List.generate(o.recentActivity.length.clamp(0, 6), (i) {
              final a = o.recentActivity[i];
              final meta = _activityMeta(a.type);
              final last = i == o.recentActivity.length.clamp(0, 6) - 1;
              return InkWell(
                onTap: () => _openActivity(a),
                borderRadius: BorderRadius.circular(i == 0 ? 18 : 0),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.divider, width: 0.6))),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: meta.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(meta.$1, color: meta.$2, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(a.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(CurrencyUtils.formatCompact(a.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  void _openActivity(HomeActivity a) {
    switch (a.type) {
      case 'order':
        if (a.id != null && a.id!.isNotEmpty) context.go('/orders/${a.id}');
        break;
      case 'payment':
        context.go('/payments');
        break;
      default:
        _soon('Purchase details');
    }
  }

  (IconData, Color) _activityMeta(String type) {
    switch (type) {
      case 'order':
        return (Icons.receipt_long_outlined, AppColors.primary);
      case 'purchase':
        return (Icons.shopping_bag_outlined, AppColors.success);
      case 'payment':
        return (Icons.payments_outlined, AppColors.info);
      default:
        return (Icons.circle_outlined, AppColors.textSecondary);
    }
  }

  // ---------------- shared ----------------
  Widget _sectionHeader(String title, String action, VoidCallback onAction) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const Spacer(),
        GestureDetector(onTap: onAction, child: Text(action, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );
}

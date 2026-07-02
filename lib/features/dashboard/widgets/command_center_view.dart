import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/command_center_model.dart';
import '../providers/command_center_provider.dart';

const _orange = Color(0xFFF59E0B);
const _indigo = Color(0xFF6366F1);
const _palette = [Color(0xFF6366F1), Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4), Color(0xFFA855F7)];

// Persona → available lenses (mirrors the web DashboardShell). First entry = default.
const _persona = {
  'accountant': 'finance', 'accounts': 'finance', 'collection_rep': 'finance',
  'estimator': 'estimating',
  'admin': 'exec', 'manager': 'exec', 'super_admin': 'exec', 'super_user': 'exec', 'ho_user': 'exec',
  'site_admin': 'operations', 'technician': 'operations', 'production': 'operations', 'dispatch': 'operations',
};
const _lensesFor = {
  'finance': ['finance', 'mywork'],
  'estimating': ['estimating', 'mywork'],
  'exec': ['executive', 'operations', 'finance', 'mywork'],
  'operations': ['operations', 'mywork'],
};
const _lensMeta = {
  'executive': ('🎛', 'Executive'),
  'operations': ('🛠', 'Operations'),
  'finance': ('💵', 'Finance'),
  'estimating': ('📐', 'Estimating'),
  'mywork': ('🙋', 'My Work'),
};

/// The ERP executive command center — a lens-tabbed home mirroring the web
/// DashboardShell (Executive / Operations / Finance / My Work). Rendered in place
/// of the billing hero+P&L for companies that run the construction-ERP modules.
class CommandCenterView extends ConsumerStatefulWidget {
  const CommandCenterView({super.key});
  @override
  ConsumerState<CommandCenterView> createState() => _CommandCenterViewState();
}

class _CommandCenterViewState extends ConsumerState<CommandCenterView> {
  String? _lens;

  bool _has(String m) {
    final mods = ref.read(authProvider).user?.effectiveModules ?? const [];
    return mods.isEmpty || mods.contains(m);
  }

  List<String> _lenses() {
    final role = ref.read(authProvider).user?.effectiveRole ?? 'operations';
    final persona = _persona[role] ?? 'operations';
    return _lensesFor[persona] ?? const ['operations'];
  }

  @override
  Widget build(BuildContext context) {
    final cc = ref.watch(commandCenterProvider);
    final lenses = _lenses();
    final lens = _lens ?? lenses.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cc.action != null && cc.action!.totalItems > 0) ...[
          _attentionHeader(cc.action!),
          const SizedBox(height: 14),
        ],
        if (lenses.length > 1) ...[
          _lensTabs(lenses, lens),
          const SizedBox(height: 16),
        ],
        // Money band (persona-based; admins/finance see cash & AR/AP).
        if (cc.money != null) ...[
          _moneyBand(cc.money!),
          const SizedBox(height: 18),
        ],
        // Lens body
        if (lens == 'executive') _execLens(cc),
        if (lens == 'operations') _opsLens(cc),
        if (lens == 'finance') _finLens(cc),
        if (lens == 'estimating') _estLens(cc),
        if (lens == 'mywork') _myWorkLens(cc),
        const SizedBox(height: 18),
        // Action rail (the web's right column) — personal actions in My Work.
        _actionRail(lens == 'mywork' ? cc.mineAction : cc.action, mine: lens == 'mywork'),
        const SizedBox(height: 8),
      ],
    );
  }

  // ───────── header + tabs ─────────
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

  Widget _lensTabs(List<String> lenses, String active) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: lenses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final l = lenses[i];
          final meta = _lensMeta[l] ?? ('', l);
          final on = l == active;
          return GestureDetector(
            onTap: () => setState(() => _lens = l),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: on ? const LinearGradient(colors: [_indigo, Color(0xFF4F46E5)]) : null,
                color: on ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: on ? Colors.transparent : AppColors.border),
                boxShadow: on ? [BoxShadow(color: _indigo.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))] : null,
              ),
              child: Text('${meta.$1} ${meta.$2}',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.textSecondary)),
            ),
          );
        },
      ),
    );
  }

  // ───────── money band ─────────
  Widget _moneyBand(MoneyBand mb) {
    String m(double? v) => v == null ? '—' : CurrencyUtils.formatCompact(v);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _kpiCard('Cash on hand', m(mb.cashOnHand), Icons.account_balance_wallet_outlined, AppColors.primary),
        _kpiCard('Overdue AR', m(mb.overdueAR), Icons.schedule_outlined, (mb.overdueAR ?? 0) > 0 ? AppColors.danger : AppColors.success,
            sub: mb.overdueARCount > 0 ? '${mb.overdueARCount} invoices' : null),
        _kpiCard('Payables', m(mb.payables), Icons.account_balance_outlined, _orange,
            sub: mb.payablesCount > 0 ? '${mb.payablesCount} bills' : null),
        _kpiCard('Margin', mb.marginPct == null ? '—' : '${mb.marginPct}%', Icons.trending_up, AppColors.success),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color, {String? sub}) {
    return _card(child: Padding(
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
    ));
  }

  // ───────── lenses ─────────
  Widget _execLens(CommandCenterState cc) {
    final p = cc.projects, m = cc.machinery, t = cc.tenders;
    return Column(children: [
      if (_has('projects') && p != null)
        _widget('🏗 Projects', 'projects', rows: [
          ('WON value', CurrencyUtils.formatCompact(p.wonValue)),
          ('Active', '${p.totalProjects}'),
          ('Outstanding', CurrencyUtils.formatCompact(p.outstanding)),
        ]),
      if (_has('machinery') && m != null)
        _widget('🚜 Machinery', 'machinery', rows: [
          ('Fleet', '${m.total}'),
          ('Under maint.', '${m.statusCounts['UNDER_MAINTENANCE'] ?? 0}'),
          ('Maint MTD', CurrencyUtils.formatCompact(m.maintenanceCostMtd)),
        ]),
      if (_has('tender') && t != null)
        _widget('📑 Tenders', 'tenders', rows: [
          ('Live', '${t.total}'),
          ('Win rate', t.winRate == null ? '—' : '${t.winRate}%'),
          ('EMD / BG', CurrencyUtils.formatCompact(t.instrumentsBlockedValue)),
        ]),
      if (_has('projects') && p != null)
        _widget('📊 Project P&L', 'accounts', rows: [
          ('Est margin', CurrencyUtils.formatCompact(p.estMargin)),
          ('Actual margin', CurrencyUtils.formatCompact(p.actualMargin)),
          ('Variance', CurrencyUtils.formatCompact(p.costVariance)),
        ]),
      if (_has('projects') && p != null)
        _donutCard('Project pipeline', 'projects', p.counts.map((k, v) => MapEntry(_pretty(k), v.toDouble())), '${p.totalProjects}', 'projects'),
      if (_has('tender') && t != null)
        _donutCard('Tender outcomes', 'tenders', {
          'Won': t.winCount.toDouble(),
          'Lost': t.lossCount.toDouble(),
          'In-progress': (t.total - t.winCount - t.lossCount).clamp(0, t.total).toDouble(),
        }, '${t.winRate ?? '—'}%', 'win rate'),
    ]);
  }

  Widget _opsLens(CommandCenterState cc) {
    final p = cc.projects, m = cc.machinery, t = cc.tenders;
    final proc = cc.action?.byModule['Procurement'] ?? const [];
    return Column(children: [
      if (_has('projects') && p != null)
        _widget('🏗 Projects', 'projects', rows: [
          ('WON value', CurrencyUtils.formatCompact(p.wonValue)),
          ('Active', '${p.totalProjects}'),
          ('Work orders', '${p.workOrders}'),
          ('Outstanding', CurrencyUtils.formatCompact(p.outstanding)),
        ]),
      if (_has('machinery') && m != null)
        _widget('🚜 Machinery', 'machinery', rows: [
          ('Fleet', '${m.total}'),
          ('Under maint.', '${m.statusCounts['UNDER_MAINTENANCE'] ?? 0}'),
          ('Docs expiring', '${m.docsExpiring}'),
          ('Open jobs', '${m.jobsOpen}'),
        ]),
      if (_has('tender') && t != null)
        _widget('📑 Tenders', 'tenders', rows: [
          ('Live', '${t.total}'),
          ('Win rate', t.winRate == null ? '—' : '${t.winRate}%'),
          ('Closing soon', '${t.upcomingDeadlines}'),
        ]),
      if (_has('vendor_purchases'))
        _widget('📦 Procurement', 'procurement', rows: proc.isNotEmpty
            ? proc.take(4).map((i) => (i.title.replaceAll(RegExp(r' to approve| awaiting.*'), ''), '${i.count}')).toList()
            : [('Pending actions', 'None 🎉')]),
      if (_has('machinery') && m != null)
        _donutCard('Fleet status', 'machinery', m.statusCounts.map((k, v) => MapEntry(_pretty(k), v.toDouble())), '${m.total}', 'machines'),
      if (_has('projects') && p != null)
        _donutCard('Project pipeline', 'projects', p.counts.map((k, v) => MapEntry(_pretty(k), v.toDouble())), '${p.totalProjects}', 'projects'),
    ]);
  }

  Widget _finLens(CommandCenterState cc) {
    final mb = cc.money, p = cc.projects;
    return Column(children: [
      _widget('💵 Cash', 'accounts', rows: [
        ('On hand', CurrencyUtils.formatCompact(mb?.cashOnHand ?? 0)),
      ]),
      _widget('📥 Receivables / Payables', 'reports', rows: [
        ('Overdue AR', CurrencyUtils.formatCompact(mb?.overdueAR ?? 0)),
        ('Payables', CurrencyUtils.formatCompact(mb?.payables ?? 0)),
        if (p != null) ('Retention held', CurrencyUtils.formatCompact(p.retentionHeld)),
      ]),
      if (_has('projects') && p != null)
        _widget('📊 Project P&L', 'accounts', rows: [
          ('Est margin', CurrencyUtils.formatCompact(p.estMargin)),
          ('Actual margin', CurrencyUtils.formatCompact(p.actualMargin)),
          ('Cost variance', CurrencyUtils.formatCompact(p.costVariance)),
        ]),
      _donutCard('Receivables vs Payables', 'reports', {
        'Receivable': (mb?.overdueAR ?? 0),
        'Payable': (mb?.payables ?? 0),
      }, CurrencyUtils.formatCompact((mb?.overdueAR ?? 0) + (mb?.payables ?? 0)), 'exposure', money: true),
    ]);
  }

  Widget _estLens(CommandCenterState cc) {
    final p = cc.projects;
    return Column(children: [
      if (p != null)
        _widget('🏗 My Projects', 'projects', rows: [
          ('WON value', CurrencyUtils.formatCompact(p.wonValue)),
          ('Active', '${p.totalProjects}'),
          ('Work orders', '${p.workOrders}'),
          ('Outstanding', CurrencyUtils.formatCompact(p.outstanding)),
        ]),
      if (p != null)
        _widget('📝 Quotes & RFIs', 'projects', rows: [
          ('Quotes pending', '${p.quotesAwaitingApproval}'),
        ]),
      if (p != null)
        _donutCard('Pipeline — hit rate', 'projects', p.counts.map((k, v) => MapEntry(_pretty(k), v.toDouble())), '${p.totalProjects}', 'projects'),
    ]);
  }

  Widget _myWorkLens(CommandCenterState cc) {
    final w = cc.myWork;
    if (w == null) return const SizedBox.shrink();
    return Column(children: [
      _widget('🏗 My Projects', 'projects', rows: [
        ('Created by me', '${w.myProjects}'),
        ('My WON value', CurrencyUtils.formatCompact(w.myWonValue)),
      ]),
      _widget('📝 My Quotes & RFIs', 'projects', rows: [
        ('My estimates', '${w.myEstimates}'),
        ('Pending approval', '${w.myQuotesPending}'),
        ('My open RFIs', '${w.myOpenRfis}'),
      ]),
      if (_has('tender'))
        _widget('📑 My Tenders', 'tenders', rows: [('Active, created by me', '${w.myTenders}')]),
      if (_has('vendor_purchases'))
        _widget('📦 My Procurement', 'procurement', rows: [
          ('My open requisitions', '${w.myRequisitions}'),
          ('My POs', '${w.myPOs}'),
        ]),
    ]);
  }

  // ───────── building blocks ─────────
  Widget _widget(String title, String route, {required List<(String, String)> rows}) {
    final show = rows.where((r) => r.$1.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _head(title, route),
          const SizedBox(height: 6),
          ...List.generate(show.length, (i) => Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(border: Border(top: i == 0 ? BorderSide.none : const BorderSide(color: AppColors.divider, width: 0.6))),
                child: Row(children: [
                  Expanded(child: Text(show[i].$1, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                  Text(show[i].$2, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ]),
              )),
        ]),
      )),
    );
  }

  Widget _donutCard(String title, String route, Map<String, double> map, String center, String sub, {bool money = false}) {
    final entries = map.entries.where((e) => e.value > 0).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _head(title, route),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const SizedBox(height: 60, child: Center(child: Text('No data', style: TextStyle(color: AppColors.textMuted))))
          else
            Row(children: [
              SizedBox(
                width: 120, height: 120,
                child: Stack(alignment: Alignment.center, children: [
                  PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 38,
                    sections: List.generate(entries.length, (i) => PieChartSectionData(
                          value: entries[i].value, color: _palette[i % _palette.length], radius: 16, showTitle: false)),
                  )),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ]),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(entries.length, (i) {
                  final e = entries[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(width: 9, height: 9, decoration: BoxDecoration(color: _palette[i % _palette.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                      Text(money ? CurrencyUtils.formatCompact(e.value) : '${e.value.toInt()}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ]),
                  );
                })),
              ),
            ]),
        ]),
      )),
    );
  }

  Widget _actionRail(ActionCenter? ac, {required bool mine}) {
    Color sev(String s) => s == 'high' ? AppColors.danger : (s == 'medium' ? _orange : AppColors.textMuted);
    return _card(child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_indigo.withValues(alpha: 0.08), AppColors.surface]),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: const Border(bottom: BorderSide(color: AppColors.divider, width: 0.6)),
        ),
        child: Row(children: [
          Text(mine ? '⚡ My Actions' : '⚡ Action Center', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Spacer(),
          if ((ac?.totalItems ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: _indigo, borderRadius: BorderRadius.circular(20)),
              child: Text('${ac!.totalItems}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
      if (ac == null)
        const Padding(padding: EdgeInsets.all(28), child: Text('Loading…', style: TextStyle(color: AppColors.textMuted)))
      else if (ac.items.isEmpty)
        const Padding(padding: EdgeInsets.all(28), child: Text('All clear — nothing needs action 🎉', style: TextStyle(color: AppColors.textMuted)))
      else
        ...List.generate(ac.items.length, (i) {
          final it = ac.items[i];
          final c = sev(it.severity);
          final last = i == ac.items.length - 1;
          final route = _actionRoute(it.actionUrl);
          final row = Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: c, width: 3),
                bottom: BorderSide(color: last ? Colors.transparent : AppColors.divider, width: 0.6),
              ),
            ),
            child: Row(children: [
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
              // Chevron only when this item leads somewhere on mobile.
              if (route != null) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted)),
            ]),
          );
          // Tappable only where a mobile screen exists; otherwise a read-only glance.
          return route == null ? row : InkWell(onTap: () => context.go(route), child: row);
        }),
    ]));
  }

  Widget _head(String title, String route) {
    final r = _routeFor(route);
    return Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
      // Only offer "Open →" when the module actually has a mobile screen; the rest
      // (Projects, Machinery, Tenders, Accounts) are read-only glances managed on web.
      if (r != null)
        GestureDetector(onTap: () => context.go(r), child: const Text('Open →', style: TextStyle(color: _indigo, fontWeight: FontWeight.w700, fontSize: 12.5))),
    ]);
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

  String _pretty(String k) => k.isEmpty ? k : k[0].toUpperCase() + k.substring(1).toLowerCase().replaceAll('_', ' ');

  // Widget card → mobile route, or null if the module is web-only (read-only glance).
  String? _routeFor(String key) {
    switch (key) {
      case 'reports':
        return '/reports';
      case 'procurement':
        return '/purchases';
      case 'projects':
        return '/projects';
      case 'machinery':
        return '/machinery';
      case 'tenders':
        return '/tenders';
      default:
        return null; // accounts → managed on web
    }
  }

  // Action-center item URL → mobile route, or null when there's no mobile screen.
  String? _actionRoute(String? url) {
    const map = {
      '/reports/outstanding': '/reports',
      '/vendor-payments': '/purchases',
      '/procurement': '/purchases',
      '/site-logistics': '/site-logistics',
      '/correspondence': '/correspondence?scope=awaiting',
      '/machinery': '/machinery',
      '/tenders': '/tenders',
      '/tenders/instruments': '/tenders',
    };
    return url == null ? null : map[url];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/advisor_model.dart';
import '../providers/insights_providers.dart';
import '../widgets/insight_ui.dart';

/// Sales & Customer Advisor — parity with the web SalesAdvisorPage. Two-step:
/// GET returns a cached analysis (or nothing); Run/Re-run POSTs /run to compute.
/// Toggle Customer Health | Product Performance, filter by classification, read
/// AI recommendations per row. Gate: `sales_intelligence` (route guard).
class SalesAdvisorScreen extends ConsumerStatefulWidget {
  const SalesAdvisorScreen({super.key});
  @override
  ConsumerState<SalesAdvisorScreen> createState() => _SalesAdvisorScreenState();
}

class _FilterDef {
  final String key;
  final String label;
  final List<String>? classes;
  const _FilterDef(this.key, this.label, [this.classes]);
}

const _customerFilters = <_FilterDef>[
  _FilterDef('all', 'All'),
  _FilterDef('action', 'Needs Action', ['HIGH_RISK_DEBT', 'CREDIT_WARNING', 'CHURNING', 'DECLINING', 'SLOW_PAYER']),
  _FilterDef('high_risk', 'High Risk', ['HIGH_RISK_DEBT', 'CREDIT_WARNING']),
  _FilterDef('churning', 'Churning', ['CHURNING', 'DECLINING']),
  _FilterDef('new', 'New', ['NEW']),
  _FilterDef('champion', 'Champion', ['CHAMPION', 'LOYAL']),
  _FilterDef('healthy', 'Healthy', ['HEALTHY']),
  _FilterDef('inactive', 'Inactive', ['INACTIVE']),
];

const _productFilters = <_FilterDef>[
  _FilterDef('all', 'All'),
  _FilterDef('action', 'Needs Action', ['FADING', 'STALLED', 'NICHE']),
  _FilterDef('rising', 'Rising', ['STAR', 'RISING']),
  _FilterDef('workhorse', 'Workhorse', ['WORKHORSE']),
  _FilterDef('healthy', 'Healthy', ['HEALTHY']),
];

class _SalesAdvisorScreenState extends ConsumerState<SalesAdvisorScreen> {
  String _view = 'customers'; // 'customers' | 'products'
  String _customerFilter = 'all';
  String _productFilter = 'all';
  String? _seenGeneratedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(salesAdvisorProvider.notifier).load());
  }

  String _money(num v) => CurrencyUtils.formatCompact(v);

  /// Mirror the web: default the filter to "Needs Action" when there's anything to act on.
  void _applyDefaultFilters(SalesAdvisor r) {
    if (r.generatedAt == _seenGeneratedAt) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cc = r.customerCounts;
      final pc = r.productCounts;
      setState(() {
        _seenGeneratedAt = r.generatedAt;
        _customerFilter = (cc.highRiskDebt + cc.creditWarning + cc.churning + cc.declining + cc.slowPayer) > 0 ? 'action' : 'all';
        _productFilter = (pc.fading + pc.stalled + pc.niche) > 0 ? 'action' : 'all';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesAdvisorProvider);
    final result = state.result;
    if (result != null && result.hasAnalysis) _applyDefaultFilters(result);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sales Advisor')),
      body: Column(
        children: [
          _header(state),
          const Divider(height: 1),
          Expanded(child: _body(state)),
        ],
      ),
    );
  }

  Widget _header(SalesAdvisorState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: state.mode,
            isDense: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            ),
            items: kComparisonPeriods.map((p) => DropdownMenuItem(value: p.value, child: Text(p.label, style: const TextStyle(fontSize: 12.5)))).toList(),
            onChanged: state.running ? null : (v) => ref.read(salesAdvisorProvider.notifier).setMode(v ?? 'last_30_days'),
          ),
        ),
        const SizedBox(width: 10),
        // Bounded width: an ElevatedButton.icon as a non-flex Row child (next to an
        // Expanded) is otherwise measured under unbounded width and asserts in layout.
        SizedBox(
          width: 132,
          child: ElevatedButton.icon(
            onPressed: state.running ? null : () => ref.read(salesAdvisorProvider.notifier).run(),
            icon: state.running
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 17),
            label: Text(state.running ? 'Analysing…' : (state.hasResult ? 'Re-run' : 'Run'), overflow: TextOverflow.ellipsis),
          ),
        ),
      ]),
    );
  }

  Widget _body(SalesAdvisorState state) {
    if (state.running) return _centerStatus(Icons.insights_outlined, 'Analysing sales and customer data…', 'Computing metrics and preparing recommendations.');
    if (state.checking && state.result == null) return const Center(child: CircularProgressIndicator());
    if (state.error != null) {
      return _centerStatus(Icons.error_outline, 'Analysis failed', state.error!, color: AppColors.danger);
    }
    final r = state.result;
    if (r == null || !r.hasAnalysis) return _emptyState();

    return RefreshIndicator(
      onRefresh: () => ref.read(salesAdvisorProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (r.generatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Generated ${r.generatedAt}${r.periodLabel != null ? ' · ${r.periodLabel}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
          if (r.aiError != null) _aiErrorBanner(r.aiError!),
          _statBar(r),
          if ((r.summary != null && r.summary!.isNotEmpty) || r.topActions.isNotEmpty) _summaryCard(r),
          _viewToggle(),
          const SizedBox(height: 12),
          if (_view == 'customers') ..._customerList(r) else ..._productList(r),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statBar(SalesAdvisor r) {
    final cc = r.customerCounts;
    final pc = r.productCounts;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        statChip('Total Customers', '${cc.total}'),
        statChip('High Risk', '${cc.highRiskDebt + cc.creditWarning}', bg: AppColors.dangerLight, fg: AppColors.danger),
        statChip('Churning', '${cc.churning + cc.declining}', bg: AppColors.warningLight, fg: const Color(0xFFB45309)),
        statChip('Champion', '${cc.champion + cc.loyal}', bg: AppColors.successLight, fg: AppColors.success),
        statChip('Total Products', '${pc.total}'),
        statChip('Stars', '${pc.star + pc.rising}', bg: AppColors.successLight, fg: AppColors.success),
        statChip('Fading', '${pc.fading}', bg: AppColors.warningLight, fg: const Color(0xFFB45309)),
        statChip('Stalled', '${pc.stalled}', bg: AppColors.dangerLight, fg: AppColors.danger),
      ]),
    );
  }

  Widget _summaryCard(SalesAdvisor r) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF99F6E4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0F766E)),
            SizedBox(width: 6),
            Text('AI Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F766E))),
          ]),
          if (r.summary != null && r.summary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.summary!, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF134E4A))),
          ],
          if (r.topActions.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...List.generate(r.topActions.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i + 1}. ${r.topActions[i]}', style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF134E4A))),
                )),
          ],
        ]),
      );

  Widget _viewToggle() => Row(children: [
        _toggleBtn('Customer Health', _view == 'customers', () => setState(() => _view = 'customers')),
        const SizedBox(width: 8),
        _toggleBtn('Product Performance', _view == 'products', () => setState(() => _view = 'products')),
      ]);

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? AppColors.primary : AppColors.border),
            ),
            child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );

  Widget _filterPills(List<_FilterDef> filters, String active, ValueChanged<String> onPick) => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final f = filters[i];
            final on = f.key == active;
            return InkWell(
              onTap: () => onPick(f.key),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFF0F766E) : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: on ? const Color(0xFF0F766E) : AppColors.border),
                ),
                child: Text(f.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.textSecondary)),
              ),
            );
          },
        ),
      );

  // ── Customers ──────────────────────────────────────────────────────────────
  List<Widget> _customerList(SalesAdvisor r) {
    final f = _customerFilters.firstWhere((x) => x.key == _customerFilter, orElse: () => _customerFilters.first);
    final rows = f.classes == null ? r.customers : r.customers.where((c) => f.classes!.contains(c.classification)).toList();
    return [
      _filterPills(_customerFilters, _customerFilter, (k) => setState(() => _customerFilter = k)),
      const SizedBox(height: 12),
      if (r.customers.isEmpty)
        _inlineNote('No active customers found.')
      else if (rows.isEmpty)
        _inlineNote('No customers match the current filter.')
      else
        ...rows.map(_customerCard),
    ];
  }

  Widget _customerCard(SalesCustomerRow c) => _rowCard(
        title: c.customerName,
        subtitle: [c.city, c.representativeName].where((e) => e != null && e.isNotEmpty).join(' · '),
        classification: c.classification,
        metrics: [
          _metric('Orders', '${c.orderCurrentPeriod} / ${c.orderPriorPeriod}'),
          _metric('Revenue', _money(c.revenueCurrentPeriod)),
          _metric('Outstanding', _money(c.outstandingBalance), color: c.outstandingBalance > 0 ? AppColors.danger : null),
          if (c.overdueAmount > 0) _metric('Overdue', _money(c.overdueAmount), color: AppColors.danger),
          _metric('Avg Delay', c.avgPaymentDelayDays == null ? '—' : '${c.avgPaymentDelayDays!.toStringAsFixed(1)}d'),
        ],
        advice: c.advice,
      );

  // ── Products ───────────────────────────────────────────────────────────────
  List<Widget> _productList(SalesAdvisor r) {
    final f = _productFilters.firstWhere((x) => x.key == _productFilter, orElse: () => _productFilters.first);
    final rows = f.classes == null ? r.products : r.products.where((p) => f.classes!.contains(p.classification)).toList();
    return [
      _filterPills(_productFilters, _productFilter, (k) => setState(() => _productFilter = k)),
      const SizedBox(height: 12),
      if (r.products.isEmpty)
        _inlineNote('No products have been invoiced in the 90-day lookback.')
      else if (rows.isEmpty)
        _inlineNote('No products match the current filter.')
      else
        ...rows.map(_productCard),
    ];
  }

  Widget _productCard(SalesProductRow p) => _rowCard(
        title: p.displayName,
        subtitle: p.category ?? '',
        classification: p.classification,
        metrics: [
          _metric('Revenue', _money(p.revenueCurrentPeriod)),
          _metric('Growth', p.revenueGrowthPct == null ? '—' : '${p.revenueGrowthPct! >= 0 ? '+' : ''}${p.revenueGrowthPct!.toStringAsFixed(1)}%',
              color: p.revenueGrowthPct == null ? null : (p.revenueGrowthPct! >= 0 ? AppColors.success : AppColors.danger)),
          _metric('Contrib', '${p.revenueContributionPct.toStringAsFixed(1)}%'),
          _metric('Qty', '${p.quantityCurrentPeriod.toStringAsFixed(2)}${p.unit != null ? ' ${p.unit}' : ''}'),
          _metric('Buyers', '${p.uniqueCustomersCurrent}'),
        ],
        advice: p.aiRecommendation ?? '',
      );

  // ── Shared row card ──────────────────────────────────────────────────────
  Widget _rowCard({required String title, required String subtitle, required String classification, required List<Widget> metrics, required String advice}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          classBadge(classification),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: metrics),
        if (advice.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF0F766E)),
            const SizedBox(width: 6),
            Expanded(child: Text(advice, style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF0F766E), fontStyle: FontStyle.italic))),
          ]),
        ],
      ]),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label ', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 11.5, color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w800)),
        ]),
      );

  // ── States / helpers ─────────────────────────────────────────────────────
  Widget _emptyState() => ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.insights_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 14),
          const Center(child: Text('No analysis yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text('Run analysis to score customer health, payment risk, and product velocity.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => ref.read(salesAdvisorProvider.notifier).run(),
              icon: const Icon(Icons.auto_awesome, size: 17),
              label: const Text('Run Analysis'),
            ),
          ),
        ],
      );

  Widget _centerStatus(IconData icon, String title, String sub, {Color? color}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: color ?? AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ]),
        ),
      );

  Widget _aiErrorBanner(String msg) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF854D0E)),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 12, color: Color(0xFF854D0E)))),
        ]),
      );

  Widget _inlineNote(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Text(msg, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
      );
}

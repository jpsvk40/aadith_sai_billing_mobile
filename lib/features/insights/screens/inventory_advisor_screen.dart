import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/advisor_model.dart';
import '../providers/insights_providers.dart';
import '../widgets/insight_ui.dart';

/// Inventory Advisor — parity with the web InventoryAdvisorPage. Two-step:
/// GET returns a cached analysis (or nothing); Run/Re-run POSTs /run to compute
/// stock health, demand velocity and AI reorder recommendations. Filter by
/// classification. Gate: `inventory_intelligence` (route guard).
class InventoryAdvisorScreen extends ConsumerStatefulWidget {
  const InventoryAdvisorScreen({super.key});
  @override
  ConsumerState<InventoryAdvisorScreen> createState() => _InventoryAdvisorScreenState();
}

class _FilterDef {
  final String key;
  final String label;
  final List<String>? classes;
  const _FilterDef(this.key, this.label, [this.classes]);
}

const _filters = <_FilterDef>[
  _FilterDef('all', 'All'),
  _FilterDef('action', 'Needs Action', ['HOT_LOW_STOCK', 'REORDER_SOON', 'LOW_STOCK_ONLY', 'HOT_OVERSTOCKED', 'SLOW_OVERSTOCKED', 'DEADSTOCK']),
  _FilterDef('low_stock', 'Low Stock', ['HOT_LOW_STOCK', 'REORDER_SOON', 'LOW_STOCK_ONLY']),
  _FilterDef('overstocked', 'Overstocked', ['HOT_OVERSTOCKED', 'SLOW_OVERSTOCKED']),
  _FilterDef('deadstock', 'Deadstock', ['DEADSTOCK']),
  _FilterDef('hot_ok', 'Hot & OK', ['HOT_OK']),
  _FilterDef('healthy', 'Healthy', ['HEALTHY']),
];

const _urgentClasses = ['HOT_LOW_STOCK', 'REORDER_SOON', 'LOW_STOCK_ONLY'];

class _InventoryAdvisorScreenState extends ConsumerState<InventoryAdvisorScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(inventoryAdvisorProvider.notifier).load());
  }

  String _qty(num? v) {
    if (v == null) return '—';
    final d = v.toDouble();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryAdvisorProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Inventory Advisor')),
      body: Column(
        children: [
          _header(state),
          const Divider(height: 1),
          Expanded(child: _body(state)),
        ],
      ),
    );
  }

  Widget _header(InventoryAdvisorState state) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          const Expanded(
            child: Text('Stock health, demand velocity & AI reorder advice.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
          const SizedBox(width: 10),
          // Bounded width: non-flex ElevatedButton.icon next to an Expanded otherwise
          // asserts under unbounded-width layout.
          SizedBox(
            width: 132,
            child: ElevatedButton.icon(
              onPressed: state.running ? null : () => ref.read(inventoryAdvisorProvider.notifier).run(),
              icon: state.running
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 17),
              label: Text(state.running ? 'Analysing…' : (state.hasResult ? 'Re-run' : 'Run'), overflow: TextOverflow.ellipsis),
            ),
          ),
        ]),
      );

  Widget _body(InventoryAdvisorState state) {
    if (state.running) return _centerStatus(Icons.inventory_2_outlined, 'Analysing your inventory…', 'Computing metrics and generating AI recommendations.');
    if (state.checking && state.result == null) return const Center(child: CircularProgressIndicator());
    if (state.error != null) return _centerStatus(Icons.error_outline, 'Analysis failed', state.error!, color: AppColors.danger);

    final r = state.result;
    if (r == null || !r.hasAnalysis) return _emptyState();

    final f = _filters.firstWhere((x) => x.key == _filter, orElse: () => _filters.first);
    final visible = f.classes == null ? r.items : r.items.where((i) => f.classes!.contains(i.classification)).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(inventoryAdvisorProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (r.generatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Last run: ${r.generatedAt}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
          if (r.counts.total == 0)
            _inlineNote('No inventory items found. Add items in Inventory → Items before running this report.')
          else ...[
            if (r.aiError != null) _aiErrorBanner(r.aiError!),
            _statBar(r.counts),
            if (r.summary != null && r.summary!.isNotEmpty) _summaryCard(r),
            _filterPills(),
            const SizedBox(height: 12),
            if (visible.isEmpty) _inlineNote('No items match the current filter.') else ...visible.map(_itemCard),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statBar(InventoryCounts c) {
    final chips = <Widget>[statChip('Total Items', '${c.total}')];
    if (c.hotLowStock > 0) chips.add(statChip('Hot — Low Stock', '${c.hotLowStock}', bg: AppColors.dangerLight, fg: AppColors.danger));
    if (c.reorderSoon > 0) chips.add(statChip('Reorder Soon', '${c.reorderSoon}', bg: const Color(0xFFFFEDD5), fg: const Color(0xFFC2410C)));
    if (c.lowStockOnly > 0) chips.add(statChip('Low Stock', '${c.lowStockOnly}', bg: const Color(0xFFFFEDD5), fg: const Color(0xFFC2410C)));
    if (c.deadstock > 0) chips.add(statChip('Deadstock', '${c.deadstock}', bg: const Color(0xFFF1F5F9), fg: const Color(0xFF475569)));
    if (c.hotOverstocked > 0) chips.add(statChip('Hot Overstocked', '${c.hotOverstocked}', bg: AppColors.warningLight, fg: const Color(0xFFB45309)));
    if (c.slowOverstocked > 0) chips.add(statChip('Slow Overstocked', '${c.slowOverstocked}', bg: const Color(0xFFFEF9C3), fg: const Color(0xFF854D0E)));
    if (c.hotOk > 0) chips.add(statChip('Hot & Healthy', '${c.hotOk}', bg: AppColors.successLight, fg: AppColors.success));
    if (c.healthy > 0) chips.add(statChip('Healthy', '${c.healthy}', bg: AppColors.infoLight, fg: AppColors.primaryDark));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(spacing: 10, runSpacing: 10, children: chips),
    );
  }

  Widget _summaryCard(InventoryAdvisor r) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF99F6E4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0F766E)),
            SizedBox(width: 6),
            Text('AI Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F766E))),
          ]),
          const SizedBox(height: 8),
          Text(r.summary!, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF1E293B))),
          if (r.topActions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Top Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F766E))),
            const SizedBox(height: 4),
            ...List.generate(r.topActions.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i + 1}. ${r.topActions[i]}', style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF1E293B))),
                )),
          ],
        ]),
      );

  Widget _filterPills() => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final f = _filters[i];
            final on = f.key == _filter;
            return InkWell(
              onTap: () => setState(() => _filter = f.key),
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

  Widget _itemCard(InventoryItemRow it) {
    final urgent = _urgentClasses.contains(it.classification);
    final unit = it.unit ?? '';
    Widget trend;
    if (it.velocityChangePct == null) {
      trend = _metric('Trend', '—');
    } else {
      final pos = it.velocityChangePct! > 0;
      final neg = it.velocityChangePct! < 0;
      trend = _metric('Trend', '${pos ? '+' : ''}${_qty(it.velocityChangePct)}%', color: pos ? AppColors.success : (neg ? AppColors.danger : null));
    }
    Widget daysLeft;
    if (it.daysOfStock == null) {
      daysLeft = _metric('Days Left', '∞');
    } else {
      final d = it.daysOfStock!;
      daysLeft = _metric('Days Left', '${_qty(d)}d', color: d < 15 ? AppColors.danger : (d < 30 ? const Color(0xFFC2410C) : null));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFFF8F8) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgent ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.itemName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (it.category != null && it.category!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(it.category!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
              if (!it.hasLinkedProduct)
                const Text('standalone', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
            ]),
          ),
          const SizedBox(width: 8),
          classBadge(it.classification),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metric('Stock', '${_qty(it.currentStock)} $unit'.trim(), color: urgent ? AppColors.danger : null),
          _metric('Reorder', it.reorderLevel != null ? _qty(it.reorderLevel) : '—'),
          _metric('Max', it.maxLevel != null ? _qty(it.maxLevel) : '—'),
          _metric('Demand 30d', it.hasLinkedProduct ? _qty(it.demandTrailing30) : '—'),
          _metric('Prior 30d', it.hasLinkedProduct ? _qty(it.demandPrior30) : '—'),
          trend,
          daysLeft,
          if (it.procuredTrailing30 != null && it.procuredTrailing30! > 0) _metric('Procured 30d', _qty(it.procuredTrailing30)),
        ]),
        if (it.aiRecommendation != null && it.aiRecommendation!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF0F766E)),
            const SizedBox(width: 6),
            Expanded(child: Text(it.aiRecommendation!, style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF0F766E), fontStyle: FontStyle.italic))),
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
          const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 14),
          const Center(child: Text('No analysis yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text('Run analysis to compute stock health, demand velocity, and AI recommendations.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => ref.read(inventoryAdvisorProvider.notifier).run(),
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

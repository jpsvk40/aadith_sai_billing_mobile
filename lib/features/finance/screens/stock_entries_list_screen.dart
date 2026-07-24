import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/inventory_transaction_model.dart';
import '../../../data/providers/financial_year_provider.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/stock_entries_provider.dart';

const _green = Color(0xFF16A34A);

/// Posted "Stock Entries" history — the read counterpart to the create-only
/// stock entry form. Lists inventory transactions (entry #, type, date,
/// location, item summary) with Financial-Year / entry-type / date filtering,
/// search and sort. Mirrors the list on the web `StockEntriesPage`.
class StockEntriesListScreen extends ConsumerStatefulWidget {
  const StockEntriesListScreen({super.key});
  @override
  ConsumerState<StockEntriesListScreen> createState() => _StockEntriesListScreenState();
}

class _StockEntriesListScreenState extends ConsumerState<StockEntriesListScreen> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  static const _sortOptions = <SortSpec>[
    SortSpec('date', 'Date'),
    SortSpec('number', 'Entry #'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() => ref.read(stockEntriesProvider.notifier).load(
        financialYearId: _filters.financialYearId,
        dateFrom: _filters.dateFromParam,
        dateTo: _filters.dateToParam,
      );

  Future<void> _openFilters() async {
    final entries = ref.read(stockEntriesProvider).entries;
    final typeOptions = entries.map((e) => e.typeLabel).where((s) => s.isNotEmpty).toSet().toList()..sort();
    final fy = await ref.read(financialYearsProvider.future);
    if (!mounted) return;
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      financialYears: fy.years,
      selects: [
        SelectFilter(key: 'type', label: 'Entry Type', options: typeOptions),
      ],
    );
    if (res != null) {
      setState(() => _filters = res);
      _reload(); // FY / date range are server-side; type is applied in _visible
    }
  }

  Comparable? _sortValue(InventoryTransaction e, String key) {
    switch (key) {
      case 'date':
        return e.txnDate;
      case 'number':
        return e.txnNumber.toLowerCase();
    }
    return null;
  }

  List<InventoryTransaction> _visible(List<InventoryTransaction> all) {
    var list = all;
    final type = _filters.select('type');
    if (type != null && type.isNotEmpty) {
      list = list.where((e) => e.typeLabel == type).toList();
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        return e.txnNumber.toLowerCase().contains(q) ||
            e.locationName.toLowerCase().contains(q) ||
            (e.notes ?? '').toLowerCase().contains(q) ||
            (e.partyName ?? '').toLowerCase().contains(q) ||
            e.lines.any((l) => l.itemName.toLowerCase().contains(q) || l.itemCode.toLowerCase().contains(q));
      }).toList();
    }
    if (_sort != null) {
      list = applySort(list, _sort!, _sortValue);
    }
    return list;
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'INWARD':
      case 'ADJUST_IN':
      case 'TRANSFER_IN':
        return _green;
      case 'OUTWARD':
      case 'ADJUST_OUT':
      case 'TRANSFER_OUT':
        return AppColors.danger;
      case 'OPENING':
        return AppColors.info;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(financialYearsProvider); // warm the FY list for the filter sheet
    final state = ref.watch(stockEntriesProvider);
    final visible = _visible(state.entries);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Stock Entries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/finance/inventory/entries');
          if (mounted) _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
      ),
      body: state.isLoading && state.entries.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.entries.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: _reload)
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                    itemCount: visible.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(state.entries.length, visible.length);
                      return _entryCard(visible[i - 1]);
                    },
                  ),
                ),
    );
  }

  Widget _header(int total, int shown) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_green, Color(0xFF047857)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.playlist_add_check_outlined, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('posted stock entr${total == 1 ? 'y' : 'ies'}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search entry #, item, location…',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
        ),
      ),
      FilterSortButtons(
        activeFilterCount: _filters.activeCount,
        onFilterTap: _openFilters,
        sortOptions: _sortOptions,
        currentSort: _sort,
        onSortChanged: (s) => setState(() => _sort = s),
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
      ),
      const SizedBox(height: 4),
      if (shown != total)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Showing $shown of $total', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ),
      if (shown == 0)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('No stock entries', style: TextStyle(color: AppColors.textSecondary))),
        ),
    ]);
  }

  Widget _entryCard(InventoryTransaction e) {
    final c = _typeColor(e.txnType);
    final summary = e.itemSummary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () => _showDetail(e),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.inventory_2_outlined, color: c, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.txnNumber.isEmpty ? '(no number)' : e.txnNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                    _pill(e.typeLabel, c),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    [AppDateUtils.formatDisplay(e.txnDate), if (e.locationName.isNotEmpty) e.locationName].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ]),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
            ]),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.list_alt_outlined, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('${e.lineCount} item${e.lineCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              if (e.sourceLabel != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.link, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(child: Text(e.sourceLabel!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _pill(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
    );
  }

  // ─────────────────────────── Detail sheet ───────────────────────────

  void _showDetail(InventoryTransaction e) {
    final c = _typeColor(e.txnType);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(children: [
              Expanded(child: Text(e.txnNumber.isEmpty ? 'Stock Entry' : e.txnNumber, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
              _pill(e.typeLabel, c),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                _detailRow('Date', AppDateUtils.formatDisplay(e.txnDate)),
                _detailRow('Type', e.typeLabel),
                if (e.locationName.isNotEmpty) _detailRow('Location', e.locationCode.isNotEmpty ? '${e.locationName} (${e.locationCode})' : e.locationName),
                if (e.sourceLabel != null) _detailRow('Source', e.sourceLabel!),
                if (e.partyName != null) _detailRow('Party', e.partyName!),
                if (e.notes != null) _detailRow('Notes', e.notes!),
                const SizedBox(height: 14),
                Text('Items (${e.lineCount})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                if (e.lines.isEmpty)
                  const Text('No line detail on this entry.', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted))
                else
                  ...e.lines.map((l) => _lineRow(l)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 84, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _lineRow(InventoryTxnLine l) {
    final qty = l.quantity;
    final qtyStr = '${qty > 0 ? '+' : qty < 0 ? '-' : ''}${_fmtQty(qty.abs())}${l.unit.isNotEmpty ? ' ${l.unit}' : ''}';
    final qtyColor = qty < 0 ? AppColors.danger : _green;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.itemName.isEmpty ? 'Item' : l.itemName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              if (l.itemCode.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(l.itemCode, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Text(qtyStr, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: qtyColor)),
        ]),
        if (l.remarks != null) ...[
          const SizedBox(height: 6),
          Text(l.remarks!, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }

  String _fmtQty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

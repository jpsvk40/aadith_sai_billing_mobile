import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/inventory_report_repository.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../finance_reports.dart';

const _cyan = Color(0xFF0891B2);

/// Inventory stock report — mirrors the web Inventory Reports page. Two views:
///   • Stock — every item with its on-hand count + stock state (Out/Low/In/No-Reorder),
///     a Location (godown) filter (server-side), stock-state chips, search,
///     Item/Grouped roll-up toggle and Item-name / On-hand / Stock-value sort.
///   • Ledger — inventory movement history (date, txn, qty, running balance),
///     with the same Location filter plus a date range, search and sort.
/// Shared by all 3 verticals; links out to Stock Valuation.
class InventoryReportScreen extends ConsumerStatefulWidget {
  const InventoryReportScreen({super.key});
  @override
  ConsumerState<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends ConsumerState<InventoryReportScreen> {
  // Data
  List<Map<String, dynamic>> _items = const []; // stock-summary itemTotals
  List<Map<String, dynamic>> _ledger = const [];
  List<InventoryLocationOption> _locations = const [];
  Map<int, double> _costByItemId = const {};

  bool _loading = true;
  String? _error;

  // View / filter state
  String _view = 'stock'; // stock | ledger
  String _stockViewMode = 'items'; // items | grouped
  String _state = 'all'; // stock-state chip
  String _q = '';
  final _searchCtrl = TextEditingController();

  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  static const _stockSortOptions = <SortSpec>[
    SortSpec('name', 'Item name', ascending: true),
    SortSpec('qty', 'On-hand qty'),
    SortSpec('value', 'Stock value'),
  ];
  static const _ledgerSortOptions = <SortSpec>[
    SortSpec('date', 'Date'),
    SortSpec('qty', 'Qty moved'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  InventoryReportRepository get _repo => InventoryReportRepository(_client);
  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Map<String, int> get _locationIdByName => {for (final l in _locations) l.name: l.id};

  int? _selectedLocationId() {
    final name = _filters.select('location');
    if (name == null || name.isEmpty) return null;
    return _locationIdByName[name];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locId = _selectedLocationId();
      if (_view == 'ledger') {
        final ledger = await _repo.getLedger(
          locationId: locId,
          from: _filters.dateFromParam,
          to: _filters.dateToParam,
        );
        if (!mounted) return;
        setState(() {
          _ledger = ledger;
          _loading = false;
        });
      } else {
        // Unit costs are item-level (location independent) — fetch once, tolerate failure.
        if (_costByItemId.isEmpty) {
          try {
            _costByItemId = await _repo.getUnitCostByItemId();
          } catch (_) {/* value sort just falls back to 0 */}
        }
        final summary = await _repo.getStockSummary(locationId: locId);
        if (!mounted) return;
        setState(() {
          _items = summary.itemTotals;
          // Cache the full location list only from the unfiltered load, so the
          // Location dropdown keeps every option even while one is selected.
          if (locId == null && summary.locations.isNotEmpty) _locations = summary.locations;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openFilters() async {
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      // Stock view has no date dimension; the ledger does.
      showPeriods: _view == 'ledger',
      showDateRange: _view == 'ledger',
      selects: [
        SelectFilter(
          key: 'location',
          label: 'Location',
          options: _locations.map((l) => l.name).toList(),
          allLabel: 'All Locations',
        ),
      ],
    );
    if (res != null) {
      setState(() => _filters = res);
      _load(); // location + date range are resolved server-side
    }
  }

  void _switchView(String v) {
    if (v == _view) return;
    setState(() {
      _view = v;
      _sort = null;
      // Date range only applies to the ledger — drop it when leaving.
      if (v == 'stock') {
        _filters.period = null;
        _filters.dateFrom = null;
        _filters.dateTo = null;
      }
    });
    _load();
  }

  // ─────────────────────────── Stock helpers ───────────────────────────

  /// Same rules as the web report's getStockState.
  (String, String, Color) _stockState(Map<String, dynamic> r) {
    final qty = _num(r['totalQuantity']);
    final reorder = _num(r['reorderLevel']);
    if (qty <= 0) return ('out_of_stock', 'Out of Stock', const Color(0xFFDC2626));
    if (reorder > 0 && qty <= reorder) return ('low_stock', 'Low Stock', const Color(0xFFD97706));
    if (reorder <= 0) return ('no_reorder', 'No Reorder Set', const Color(0xFF0284C7));
    return ('in_stock', 'In Stock', const Color(0xFF16A34A));
  }

  String _qty(Map<String, dynamic> r) {
    final q = _num(r['totalQuantity']);
    final unit = (r['itemUnit'] ?? r['unit'] ?? r['baseUnit'] ?? '').toString();
    final s = q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
    return unit.isEmpty ? s : '$s $unit';
  }

  double _stockValue(Map<String, dynamic> r) {
    if (r.containsKey('_value')) return _num(r['_value']);
    final id = (r['itemId'] as num?)?.toInt();
    final cost = id != null ? (_costByItemId[id] ?? 0.0) : 0.0;
    return _num(r['totalQuantity']) * cost;
  }

  /// Derives the parent (product) name for grouped roll-up — product name when
  /// linked, else the item name with a trailing variant label stripped off.
  String _parentName(Map<String, dynamic> r) {
    final product = (r['productName'] ?? '').toString().trim();
    if (product.isNotEmpty) return product;
    var name = (r['displayName'] ?? r['itemName'] ?? '').toString().trim();
    final variant = (r['variantLabel'] ?? '').toString().trim();
    if (variant.isNotEmpty && name.toLowerCase().endsWith(variant.toLowerCase())) {
      name = name.substring(0, name.length - variant.length).trim();
      if (name.endsWith('-')) name = name.substring(0, name.length - 1).trim();
    }
    return name.isEmpty ? (r['itemName'] ?? '—').toString() : name;
  }

  /// Rolls individual item rows up by parent name (+ unit), summing qty / value
  /// / reorder — mirrors the web's stockViewMode = grouped.
  List<Map<String, dynamic>> _groupRows(List<Map<String, dynamic>> rows) {
    final map = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final parent = _parentName(r);
      final unit = (r['baseUnit'] ?? r['itemUnit'] ?? '').toString();
      final key = '${parent.toLowerCase()}::${unit.toLowerCase()}';
      final g = map.putIfAbsent(
        key,
        () => <String, dynamic>{
          'displayName': parent,
          'itemName': parent,
          'itemCode': '',
          'itemUnit': r['itemUnit'] ?? r['unit'] ?? r['baseUnit'] ?? '',
          'baseUnit': r['baseUnit'],
          'totalQuantity': 0.0,
          'reorderLevel': 0.0,
          '_members': 0,
          '_value': 0.0,
        },
      );
      final qty = _num(r['totalQuantity']);
      g['totalQuantity'] = _num(g['totalQuantity']) + qty;
      g['reorderLevel'] = _num(g['reorderLevel']) + _num(r['reorderLevel']);
      g['_members'] = (g['_members'] as int) + 1;
      final id = (r['itemId'] as num?)?.toInt();
      final cost = id != null ? (_costByItemId[id] ?? 0.0) : 0.0;
      g['_value'] = _num(g['_value']) + qty * cost;
    }
    return map.values.toList();
  }

  Comparable? _stockSortValue(Map<String, dynamic> r, String key) {
    switch (key) {
      case 'name':
        return (r['displayName'] ?? r['itemName'] ?? '').toString().toLowerCase();
      case 'qty':
        return _num(r['totalQuantity']);
      case 'value':
        return _stockValue(r);
    }
    return null;
  }

  List<Map<String, dynamic>> _visibleStock() {
    final q = _q.trim().toLowerCase();
    var list = _items.where((r) {
      if (_state != 'all' && _stockState(r).$1 != _state) return false;
      if (q.isEmpty) return true;
      return (r['displayName'] ?? '').toString().toLowerCase().contains(q) ||
          (r['itemName'] ?? '').toString().toLowerCase().contains(q) ||
          (r['productName'] ?? '').toString().toLowerCase().contains(q) ||
          (r['variantLabel'] ?? '').toString().toLowerCase().contains(q) ||
          (r['itemCode'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    if (_stockViewMode == 'grouped') list = _groupRows(list);
    final sort = _sort ?? (_stockViewMode == 'grouped' ? const SortSpec('name', 'Item name', ascending: true) : null);
    if (sort != null) list = applySort(list, sort, _stockSortValue);
    return list;
  }

  // ─────────────────────────── Ledger helpers ───────────────────────────

  String _txnLabel(dynamic v) {
    switch ((v ?? '').toString()) {
      case 'OPENING':
        return 'Initial Stock';
      case 'INWARD':
        return 'Inward';
      case 'OUTWARD':
        return 'Outward';
      case 'ADJUST_IN':
        return 'Adjust In';
      case 'ADJUST_OUT':
        return 'Adjust Out';
      case 'TRANSFER_IN':
        return 'Transfer In';
      case 'TRANSFER_OUT':
        return 'Transfer Out';
      default:
        return (v ?? '').toString().replaceAll('_', ' ');
    }
  }

  String _fmtDate(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtQty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Comparable? _ledgerSortValue(Map<String, dynamic> r, String key) {
    switch (key) {
      case 'date':
        return DateTime.tryParse((r['txnDate'] ?? '').toString());
      case 'qty':
        return _num(r['quantity']).abs();
    }
    return null;
  }

  List<Map<String, dynamic>> _visibleLedger() {
    final q = _q.trim().toLowerCase();
    var list = _ledger.where((r) {
      if (q.isEmpty) return true;
      return (r['displayName'] ?? '').toString().toLowerCase().contains(q) ||
          (r['itemName'] ?? '').toString().toLowerCase().contains(q) ||
          (r['txnNumber'] ?? '').toString().toLowerCase().contains(q) ||
          (r['locationName'] ?? '').toString().toLowerCase().contains(q) ||
          (r['partyName'] ?? '').toString().toLowerCase().contains(q) ||
          (r['notes'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    if (_sort != null) list = applySort(list, _sort!, _ledgerSortValue);
    return list;
  }

  // ─────────────────────────── Build ───────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/reports/view', extra: FinanceReports.inventoryValuation),
            icon: const Icon(Icons.currency_rupee, size: 16, color: Colors.white),
            label: const Text('Valuation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _view == 'ledger' ? _buildLedger() : _buildStock(),
                ),
    );
  }

  // ── Stock view ──────────────────────────────────────────────
  Widget _buildStock() {
    final counts = <String, int>{'out_of_stock': 0, 'low_stock': 0, 'in_stock': 0, 'no_reorder': 0};
    for (final r in _items) {
      counts[_stockState(r).$1] = (counts[_stockState(r).$1] ?? 0) + 1;
    }
    final visible = _visibleStock();

    const chips = <(String, String)>[
      ('all', 'All'),
      ('out_of_stock', 'Out of Stock'),
      ('low_stock', 'Low Stock'),
      ('in_stock', 'In Stock'),
      ('no_reorder', 'No Reorder'),
    ];

    return ListView(padding: const EdgeInsets.all(14), children: [
      _viewToggle(),
      const SizedBox(height: 12),
      // Hero — state counts
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_cyan, Color(0xFF0E7490)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Row(children: [
            _stat('${counts['out_of_stock']}', 'Out of stock'),
            _divider(),
            _stat('${counts['low_stock']}', 'Low stock'),
            _divider(),
            _stat('${counts['in_stock']}', 'In stock'),
            _divider(),
            _stat('${_items.length}', 'Items'),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _searchField('Search item, code…'),
      const SizedBox(height: 8),
      FilterSortButtons(
        activeFilterCount: _filters.activeCount,
        onFilterTap: _openFilters,
        sortOptions: _stockSortOptions,
        currentSort: _sort,
        onSortChanged: (s) => setState(() => _sort = s),
        padding: EdgeInsets.zero,
      ),
      const SizedBox(height: 10),
      _segmented(
        const [('items', 'Items'), ('grouped', 'Grouped')],
        _stockViewMode,
        (v) => setState(() => _stockViewMode = v),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips.map((c) {
          final sel = _state == c.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c.$2),
              selected: sel,
              selectedColor: _cyan.withValues(alpha: 0.15),
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? _cyan : AppColors.textSecondary),
              onSelected: (_) => setState(() => _state = c.$1),
            ),
          );
        }).toList()),
      ),
      const SizedBox(height: 4),
      if (visible.length != _items.length)
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text('Showing ${visible.length} of ${_items.length}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ),
      const SizedBox(height: 6),
      if (visible.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Center(child: Text('No matching items', style: TextStyle(color: AppColors.textSecondary)))),
      ...visible.map(_stockCard),
    ]);
  }

  Widget _stockCard(Map<String, dynamic> r) {
    final st = _stockState(r);
    final reorder = _num(r['reorderLevel']);
    final members = r['_members'] as int?;
    final subtitle = members != null
        ? '$members item${members == 1 ? '' : 's'}${reorder > 0 ? ' · reorder at ${reorder % 1 == 0 ? reorder.toInt() : reorder}' : ''}'
        : '${r['itemCode'] ?? ''}${reorder > 0 ? ' · reorder at ${reorder % 1 == 0 ? reorder.toInt() : reorder}' : ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: st.$3.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(members != null ? Icons.inventory_2 : Icons.inventory_2_outlined, color: st.$3, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((r['displayName'] ?? r['itemName'] ?? '—').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_qty(r), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: st.$3.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(st.$2, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: st.$3)),
          ),
        ]),
      ]),
    );
  }

  // ── Ledger view ─────────────────────────────────────────────
  Widget _buildLedger() {
    final visible = _visibleLedger();
    return ListView(padding: const EdgeInsets.all(14), children: [
      _viewToggle(),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_cyan, Color(0xFF0E7490)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Row(children: [
            const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_ledger.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                Text('stock movement${_ledger.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _searchField('Search item, txn #, party…'),
      const SizedBox(height: 8),
      FilterSortButtons(
        activeFilterCount: _filters.activeCount,
        onFilterTap: _openFilters,
        sortOptions: _ledgerSortOptions,
        currentSort: _sort,
        onSortChanged: (s) => setState(() => _sort = s),
        padding: EdgeInsets.zero,
      ),
      const SizedBox(height: 4),
      if (visible.length != _ledger.length)
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text('Showing ${visible.length} of ${_ledger.length}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ),
      const SizedBox(height: 6),
      if (visible.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Center(child: Text('No stock movements', style: TextStyle(color: AppColors.textSecondary)))),
      ...visible.map(_ledgerCard),
    ]);
  }

  Widget _ledgerCard(Map<String, dynamic> r) {
    final qty = _num(r['quantity']);
    final inward = qty >= 0;
    final c = inward ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final unit = (r['itemUnit'] ?? '').toString();
    final after = _num(r['afterQuantity']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text((r['displayName'] ?? r['itemName'] ?? '—').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text('${inward ? '+' : '-'}${_fmtQty(qty.abs())}${unit.isNotEmpty ? ' $unit' : ''}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: c)),
        ]),
        const SizedBox(height: 5),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(_txnLabel(r['txnType']), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [_fmtDate(r['txnDate']), if ((r['txnNumber'] ?? '').toString().isNotEmpty) r['txnNumber'].toString(), if ((r['locationName'] ?? '').toString().isNotEmpty) r['locationName'].toString()].join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          Text('bal ${_fmtQty(after)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        if ((r['partyName'] ?? '').toString().isNotEmpty || (r['linkedNumber'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            [if ((r['referenceLabel'] ?? '').toString().isNotEmpty) r['referenceLabel'].toString(), if ((r['linkedNumber'] ?? '').toString().isNotEmpty) r['linkedNumber'].toString(), if ((r['partyName'] ?? '').toString().isNotEmpty) r['partyName'].toString()].join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ]),
    );
  }

  // ─────────────────────────── Small widgets ───────────────────────────

  Widget _viewToggle() => _segmented(
        const [('stock', 'Stock'), ('ledger', 'Ledger')],
        _view,
        _switchView,
      );

  Widget _segmented(List<(String, String)> opts, String value, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: opts.map((o) {
          final sel = o.$1 == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? _cyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  o.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _searchField(String hint) => TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          suffixIcon: _q.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _q = '');
                  },
                )
              : null,
        ),
      );

  Widget _stat(String v, String l) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.78))),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.22), margin: const EdgeInsets.symmetric(horizontal: 10));
}

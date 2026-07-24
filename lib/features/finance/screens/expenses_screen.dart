import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../data/providers/financial_year_provider.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

/// Office expenses / petty cash — list + add. Create-capable spine surface.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  // Shared filter + sort state. Date/period are scoped on the server; category +
  // payment-mode selects and the sort run client-side over the loaded list.
  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final qp = <String, dynamic>{};
      final from = _filters.dateFromParam;
      final to = _filters.dateToParam;
      if (from != null) qp['dateFrom'] = from;
      if (to != null) qp['dateTo'] = to;
      if (_filters.period != null) qp['period'] = _filters.period;
      if (_filters.financialYearId != null) qp['financialYearId'] = _filters.financialYearId;
      final data = await client.get(ApiConstants.officeExpenses, queryParams: qp.isEmpty ? null : qp);
      dynamic list = data;
      if (data is Map) list = data['data'] ?? data['expenses'] ?? data['rows'] ?? data.values.firstWhere((v) => v is List, orElse: () => const []);
      if (!mounted) return;
      setState(() { _rows = (list is List ? list : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  String? _first(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  /// Distinct categories present in the loaded rows (for the Category select).
  List<String> get _categoryOptions {
    final set = <String>{};
    for (final r in _rows) {
      final c = _first(r, ['category', 'categoryName']);
      if (c != null && c.trim().isNotEmpty) set.add(c.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Rows after client-side category/mode filtering + sort (server already
  /// scoped by date/period). Used for the list and the summary card.
  List<Map<String, dynamic>> get _visible {
    var list = _rows;
    final cat = _filters.select('category');
    if (cat != null && cat.isNotEmpty) {
      list = list.where((r) => (_first(r, ['category', 'categoryName']) ?? '') == cat).toList();
    }
    final mode = _filters.select('mode');
    if (mode != null && mode.isNotEmpty) {
      list = list.where((r) => (_first(r, ['paymentMode', 'mode']) ?? '').toLowerCase() == mode.toLowerCase()).toList();
    }
    final sort = _sort;
    if (sort != null) {
      list = applySort(list, sort, (r, key) {
        if (key == 'amount') return _num(r['amount'] ?? r['totalAmount']);
        return _first(r, ['expenseDate', 'date']) ?? ''; // ISO date strings sort lexicographically
      });
    }
    return list;
  }

  Future<void> _openFilters() async {
    final fyData = await ref.read(financialYearsProvider.future);
    if (!mounted) return;
    final result = await showListFilterSheet(
      context,
      initial: _filters,
      showPeriods: true,
      showDateRange: true,
      financialYears: fyData.years,
      selects: [
        SelectFilter(key: 'category', label: 'Category', options: _categoryOptions),
        const SelectFilter(key: 'mode', label: 'Payment Mode', options: ['Cash', 'UPI']),
      ],
    );
    if (result == null) return;
    // Reload from server only when a server-side scope (date window or FY) changed.
    final serverChanged = result.dateFromParam != _filters.dateFromParam ||
        result.dateToParam != _filters.dateToParam ||
        result.financialYearId != _filters.financialYearId;
    setState(() => _filters = result);
    if (serverChanged) _load();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(financialYearsProvider); // kick off + cache FY list for the filter sheet
    final visible = _visible;
    final total = visible.fold<double>(0, (a, r) => a + _num(r['amount'] ?? r['totalAmount']));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await context.push<bool>('/finance/expenses/new');
          if (added == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: _loading && _rows.isEmpty
          ? const LoadingIndicator()
          : _error != null && _rows.isEmpty
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    FilterSortButtons(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      activeFilterCount: _filters.activeCount,
                      onFilterTap: _openFilters,
                      currentSort: _sort,
                      sortOptions: const [SortSpec('date', 'Date'), SortSpec('amount', 'Amount')],
                      onSortChanged: (s) => setState(() => _sort = s),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
                          itemCount: visible.length + 1,
                          itemBuilder: (ctx, i) {
                            if (i == 0) {
                        return Container(
                          margin: const EdgeInsets.all(14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFB45309)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(children: [
                            const Icon(Icons.request_quote_outlined, color: Colors.white, size: 26),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Total expenses', style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(CurrencyUtils.format(total), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                            ])),
                            Text('${visible.length} rows', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                          ]),
                        );
                      }
                      final r = visible[i - 1];
                      final label = _first(r, ['category', 'categoryName', 'description', 'notes', 'name']) ?? 'Expense';
                      final rawDate = _first(r, ['expenseDate', 'date']);
                      final date = rawDate != null && rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
                      final mode = _first(r, ['paymentMode', 'mode']);
                      final subtitle = [date, mode].whereType<String>().join(' · ');
                      return Container(
                        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ],
                          ])),
                          const SizedBox(width: 10),
                          Text(CurrencyUtils.format(_num(r['amount'] ?? r['totalAmount'])), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ]),
                      );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

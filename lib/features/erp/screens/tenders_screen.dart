import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/erp_list_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/erp_providers.dart';
import 'erp_common.dart';

const _accent = Color(0xFF0891B2);

/// Read-only Tenders list (manage on web) — gradient hero, status filters, search.
class TendersScreen extends ConsumerStatefulWidget {
  const TendersScreen({super.key});
  @override
  ConsumerState<TendersScreen> createState() => _TendersScreenState();
}

class _TendersScreenState extends ConsumerState<TendersScreen> {
  // Fixed pipeline stages — every stage always shows even with zero rows.
  static const _statuses = [
    'IDENTIFIED', 'SEEN', 'APPROVED_TO_BID', 'PURCHASED', 'PREBID', 'SUBMITTED',
    'OPENED', 'NEGOTIATION', 'WON', 'LOST', 'DROPPED',
  ];

  String _filter = 'all';
  String _q = '';
  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  static String _date(DateTime? d) => d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // Client-side deadline window — tolerant of a one-sided (from-only / to-only) range.
  bool _inWindow(DateTime? d) {
    final from = _filters.dateFrom;
    final to = _filters.dateTo;
    if (from == null && to == null) return true;
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (from != null && day.isBefore(DateTime(from.year, from.month, from.day))) return false;
    if (to != null && day.isAfter(DateTime(to.year, to.month, to.day))) return false;
    return true;
  }

  List<Tender> _visible(List<Tender> rows) {
    var list = rows.where((t) {
      if (_filter != 'all' && t.status != _filter) return false;
      if (!_inWindow(t.submissionDeadline)) return false;
      if (_q.isEmpty) return true;
      final s = _q.toLowerCase();
      return t.title.toLowerCase().contains(s) || t.tenderCode.toLowerCase().contains(s) || (t.authority ?? '').toLowerCase().contains(s);
    }).toList();
    if (_sort != null) {
      list = applySort<Tender>(list, _sort!, (t, key) {
        switch (key) {
          case 'date':
            return t.submissionDeadline;
          case 'value':
            return t.estimatedValue;
        }
        return null;
      });
    }
    return list;
  }

  Future<void> _openFilters() async {
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      title: 'Filter Tenders',
      showPeriods: false,
      showDateRange: true,
    );
    if (res != null) setState(() => _filters = res);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tendersListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tenders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await context.push<bool>('/tenders/create');
          if (saved == true) ref.invalidate(tendersListProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: async.when(
        loading: () => const LoadingIndicator(message: 'Loading tenders…'),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(tendersListProvider)),
        data: (rows) {
          final emd = rows.fold<double>(0, (s, t) => s + t.emdAmount);
          final filtered = _visible(rows);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(children: [
                ErpHero(gradient: const [_accent, Color(0xFF0E7490)], icon: Icons.gavel, stats: [
                  ('Tenders', '${rows.length}'),
                  ('Won', '${rows.where((t) => t.status == 'WON').length}'),
                  ('EMD blocked', CurrencyUtils.formatCompact(emd)),
                ]),
                const SizedBox(height: 12),
                ErpSearchField(hint: 'Search tender, authority, code…', onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: 10),
                FilterSortButtons(
                  padding: EdgeInsets.zero,
                  activeFilterCount: _filters.activeCount,
                  onFilterTap: _openFilters,
                  sortOptions: const [
                    SortSpec('date', 'Date'),
                    SortSpec('value', 'Value'),
                  ],
                  currentSort: _sort,
                  onSortChanged: (s) => setState(() => _sort = s),
                ),
                const SizedBox(height: 10),
                ErpFilterChips(options: buildFixedStatusOptions(_statuses, rows.map((t) => t.status)), selected: _filter, accent: _accent, onSelect: (v) => setState(() => _filter = v)),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(tendersListProvider),
                child: filtered.isEmpty
                    ? ListView(children: const [ErpEmpty(icon: Icons.gavel_outlined, text: 'No matching tenders')])
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: filtered.map(_card).toList()),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _card(Tender t) => GestureDetector(
        onTap: () => context.push('/tenders/${t.id}'),
        child: ErpCard(
          icon: Icons.gavel_outlined,
          color: _accent,
          title: t.title,
          code: t.tenderCode,
          status: t.status,
          rows: [
            if ((t.authority ?? '').isNotEmpty) ('Authority', t.authority!),
            if (t.estimatedValue > 0) ('Est. value', CurrencyUtils.formatCompact(t.estimatedValue)),
            if (t.emdAmount > 0) ('EMD', CurrencyUtils.formatCompact(t.emdAmount)),
            if (t.submissionDeadline != null) ('Submit by', _date(t.submissionDeadline)),
          ],
        ),
      );
}

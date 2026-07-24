import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/list_controls.dart';

/// Web palette for the procurement status badges (Requisition / RFQ / PO / Payment).
Color procStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
      return const Color(0xFF64748B);
    case 'SUBMITTED':
    case 'SENT':
    case 'RECEIVED':
      return const Color(0xFF2563EB);
    case 'APPROVED':
    case 'CLOSED':
    case 'PAID':
    case 'SELECTED':
      return const Color(0xFF16A34A);
    case 'REJECTED':
      return const Color(0xFFDC2626);
    case 'CANCELLED':
      return const Color(0xFF94A3B8);
    case 'RFQ_CREATED':
    case 'QUOTED':
    case 'HOLD':
      return const Color(0xFF7C3AED);
    case 'COMPARED':
    case 'PENDING':
    case 'PENDING_APPROVAL':
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF64748B);
  }
}

/// Small rounded status badge matching the web `<Badge>`.
class ProcStatusPill extends StatelessWidget {
  final String status;
  const ProcStatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = procStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

/// A single procurement tab body: search box + status ChoiceChips + shared
/// Filter/Sort controls, all applied client-side over an already-loaded list.
///
/// [T] is the row model. The hub supplies the extractors + row builder so this
/// stays generic across Requisitions / RFQs / POs / Payment Requests.
class ProcurementListView<T> extends StatefulWidget {
  final List<T>? items; // null = still loading
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  final String Function(T item) statusOf;
  final bool Function(T item, String query) searchMatches;
  final DateTime? Function(T item) dateOf;

  /// Distinct status values offered as filter chips (excluding the implicit "All").
  final List<String> statusOptions;

  final List<SortSpec> sortOptions;
  final Comparable? Function(T item, String key) sortValueOf;

  final Widget Function(BuildContext context, T item) rowBuilder;
  final Widget Function(List<T> visible)? summaryBuilder;

  final String searchHint;
  final String emptyText;

  const ProcurementListView({
    super.key,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.statusOf,
    required this.searchMatches,
    required this.dateOf,
    required this.statusOptions,
    required this.sortOptions,
    required this.sortValueOf,
    required this.rowBuilder,
    this.summaryBuilder,
    this.searchHint = 'Search...',
    this.emptyText = 'Nothing here yet.',
  });

  @override
  State<ProcurementListView<T>> createState() => _ProcurementListViewState<T>();
}

class _ProcurementListViewState<T> extends State<ProcurementListView<T>> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _status; // null = All
  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _inDateWindow(T item) {
    final w = _filters.effectiveWindow;
    final from = w?.from ?? _filters.dateFrom;
    final to = w?.to ?? _filters.dateTo;
    if (from == null && to == null) return true;
    final d = widget.dateOf(item);
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (from != null && day.isBefore(DateTime(from.year, from.month, from.day))) return false;
    if (to != null && day.isAfter(DateTime(to.year, to.month, to.day))) return false;
    return true;
  }

  List<T> _visible(List<T> all) {
    final q = _search.trim().toLowerCase();
    var rows = all.where((it) {
      if (_status != null && widget.statusOf(it) != _status) return false;
      if (q.isNotEmpty && !widget.searchMatches(it, q)) return false;
      if (!_inDateWindow(it)) return false;
      return true;
    }).toList();
    final sort = _sort;
    if (sort != null) rows = applySort(rows, sort, widget.sortValueOf);
    return rows;
  }

  Future<void> _openFilters() async {
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      showPeriods: true,
      showDateRange: true,
    );
    if (res != null) setState(() => _filters = res);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (widget.loading && items == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (widget.error != null && (items == null || items.isEmpty)) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 46, color: AppColors.danger),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(widget.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ]),
      );
    }

    final all = items ?? const [];
    final visible = _visible(all.cast<T>());

    return Column(
      children: [
        _searchField(),
        FilterSortButtons(
          activeFilterCount: _filters.activeCount,
          onFilterTap: _openFilters,
          sortOptions: widget.sortOptions,
          currentSort: _sort,
          onSortChanged: (s) => setState(() => _sort = s),
        ),
        if (widget.statusOptions.isNotEmpty) _statusChips(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: all.isEmpty
                ? _emptyList(widget.emptyText, Icons.inbox_outlined)
                : visible.isEmpty
                    ? _emptyList('No records match your filters.', Icons.search_off)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                        itemCount: visible.length + (widget.summaryBuilder != null ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          if (widget.summaryBuilder != null && i == 0) {
                            return widget.summaryBuilder!(visible);
                          }
                          final idx = widget.summaryBuilder != null ? i - 1 : i;
                          return widget.rowBuilder(ctx, visible[idx]);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: widget.searchHint,
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      );

  Widget _statusChips() {
    final options = ['All', ...widget.statusOptions];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: options.map((s) {
          final sel = (s == 'All' && _status == null) || s == _status;
          final c = s == 'All' ? AppColors.primary : procStatusColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s),
              selected: sel,
              onSelected: (_) => setState(() => _status = s == 'All' ? null : s),
              labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sel ? c : AppColors.textSecondary),
              selectedColor: c.withValues(alpha: 0.14),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: sel ? c : AppColors.border),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyList(String text, IconData icon) => ListView(
        children: [
          const SizedBox(height: 110),
          Icon(icon, size: 46, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted))),
        ],
      );
}

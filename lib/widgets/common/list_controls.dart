import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Shared filter + sort controls for list screens, giving the mobile app the
/// same filtering/sorting affordances the web portal has (quick periods, date
/// range, dropdown filters, and multi-key sort with direction toggle).
///
/// Screens keep a [ListFilterState] + a [SortSpec] in their own state, drop a
/// [FilterSortButtons] under their search box, and call [showListFilterSheet]
/// to edit filters. Server-backed filters (status/date/period) are forwarded to
/// the provider's `load()`; client-only filters and sort run over the loaded
/// list via [applySort] / helpers here.

// ─────────────────────────── Quick periods ───────────────────────────

class QuickPeriod {
  final String key;
  final String label;
  const QuickPeriod(this.key, this.label);
}

const List<QuickPeriod> kQuickPeriods = [
  QuickPeriod('thisMonth', 'This Month'),
  QuickPeriod('lastMonth', 'Last Month'),
  QuickPeriod('thisYear', 'This Year'),
  QuickPeriod('lastYear', 'Last Year'),
  QuickPeriod('last30days', 'Last 30 Days'),
  QuickPeriod('last90days', 'Last 90 Days'),
];

/// Resolves a quick-period key to an inclusive [from, to] date window.
/// Returns null when [key] is null/unknown so the caller can skip the param.
({DateTime from, DateTime to})? resolvePeriod(String? key) {
  if (key == null || key.isEmpty) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (key) {
    case 'thisMonth':
      return (from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month + 1, 0));
    case 'lastMonth':
      return (from: DateTime(now.year, now.month - 1, 1), to: DateTime(now.year, now.month, 0));
    case 'thisYear':
      return (from: DateTime(now.year, 1, 1), to: DateTime(now.year, 12, 31));
    case 'lastYear':
      return (from: DateTime(now.year - 1, 1, 1), to: DateTime(now.year - 1, 12, 31));
    case 'last30days':
      return (from: today.subtract(const Duration(days: 30)), to: today);
    case 'last90days':
      return (from: today.subtract(const Duration(days: 90)), to: today);
  }
  return null;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ─────────────────────────── Filter state ───────────────────────────

/// A single dropdown/select filter configuration.
class SelectFilter {
  final String key; // logical key, e.g. 'createdBy'
  final String label; // UI label
  final List<String> options; // selectable display values (excluding "All")
  final String allLabel;
  const SelectFilter({
    required this.key,
    required this.label,
    required this.options,
    this.allLabel = 'All',
  });
}

/// One financial year the sheet can filter by. [id] is the server value passed as
/// `financialYearId`; [label] is what's shown (e.g. "2026-27").
class FinancialYearOption {
  final String id;
  final String label;
  const FinancialYearOption({required this.id, required this.label});
}

/// Holds the active filter selections for a list screen.
class ListFilterState {
  String? period; // quick-period key
  DateTime? dateFrom;
  DateTime? dateTo;
  String? financialYearId; // server value for `financialYearId` (null = All Years)
  final Map<String, String?> selects; // SelectFilter.key -> chosen value (null = All)

  ListFilterState({this.period, this.dateFrom, this.dateTo, this.financialYearId, Map<String, String?>? selects})
      : selects = selects ?? {};

  bool get hasDateWindow => period != null || dateFrom != null || dateTo != null;

  /// Resolved [from,to] for server params — quick period wins over manual range.
  ({DateTime from, DateTime to})? get effectiveWindow {
    final p = resolvePeriod(period);
    if (p != null) return p;
    if (dateFrom != null && dateTo != null) return (from: dateFrom!, to: dateTo!);
    return null;
  }

  String? get dateFromParam {
    final w = effectiveWindow;
    return w != null ? _ymd(w.from) : (dateFrom != null ? _ymd(dateFrom!) : null);
  }

  String? get dateToParam {
    final w = effectiveWindow;
    return w != null ? _ymd(w.to) : (dateTo != null ? _ymd(dateTo!) : null);
  }

  String? select(String key) => selects[key];

  int get activeCount {
    var n = 0;
    if (period != null) n++;
    if (dateFrom != null && period == null) n++;
    if (dateTo != null && period == null) n++;
    if (financialYearId != null && financialYearId!.isNotEmpty) n++;
    n += selects.values.where((v) => v != null && v.isNotEmpty).length;
    return n;
  }

  ListFilterState clone() => ListFilterState(
        period: period,
        dateFrom: dateFrom,
        dateTo: dateTo,
        financialYearId: financialYearId,
        selects: Map.of(selects),
      );

  void clear() {
    period = null;
    dateFrom = null;
    dateTo = null;
    financialYearId = null;
    selects.clear();
  }
}

// ─────────────────────────── Sort ───────────────────────────

class SortSpec {
  final String key; // stable key, e.g. 'date'
  final String label; // 'Date'
  final bool ascending;
  const SortSpec(this.key, this.label, {this.ascending = false});

  SortSpec flipped() => SortSpec(key, label, ascending: !ascending);
  SortSpec withDir(bool asc) => SortSpec(key, label, ascending: asc);
}

/// Sorts [items] by a numeric or comparable key extracted via [valueOf].
/// Nulls sort last regardless of direction.
List<T> applySort<T>(List<T> items, SortSpec sort, Comparable? Function(T item, String key) valueOf) {
  final copy = [...items];
  copy.sort((a, b) {
    final va = valueOf(a, sort.key);
    final vb = valueOf(b, sort.key);
    if (va == null && vb == null) return 0;
    if (va == null) return 1;
    if (vb == null) return -1;
    final c = va.compareTo(vb);
    return sort.ascending ? c : -c;
  });
  return copy;
}

// ─────────────────────────── UI ───────────────────────────

/// A compact "Filters (n)" + "Sort" control row. Place it under the search box.
class FilterSortButtons extends StatelessWidget {
  final int activeFilterCount;
  final VoidCallback onFilterTap;
  final List<SortSpec> sortOptions;
  final SortSpec? currentSort;
  final ValueChanged<SortSpec>? onSortChanged;
  final EdgeInsetsGeometry padding;

  const FilterSortButtons({
    super.key,
    required this.activeFilterCount,
    required this.onFilterTap,
    this.sortOptions = const [],
    this.currentSort,
    this.onSortChanged,
    this.padding = const EdgeInsets.fromLTRB(14, 0, 14, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onFilterTap,
              icon: Badge(
                isLabelVisible: activeFilterCount > 0,
                label: Text('$activeFilterCount'),
                backgroundColor: AppColors.danger,
                child: const Icon(Icons.tune, size: 18),
              ),
              label: Text(activeFilterCount > 0 ? 'Filters · $activeFilterCount' : 'Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: activeFilterCount > 0 ? AppColors.primary : AppColors.textSecondary,
                side: BorderSide(color: activeFilterCount > 0 ? AppColors.primary : AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (sortOptions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: PopupMenuButton<String>(
                onSelected: (key) {
                  if (onSortChanged == null) return;
                  if (currentSort?.key == key) {
                    onSortChanged!(currentSort!.flipped());
                  } else {
                    final base = sortOptions.firstWhere((s) => s.key == key);
                    onSortChanged!(base);
                  }
                },
                itemBuilder: (ctx) => sortOptions.map((s) {
                  final active = currentSort?.key == s.key;
                  return PopupMenuItem<String>(
                    value: s.key,
                    child: Row(
                      children: [
                        Icon(
                          active
                              ? (currentSort!.ascending ? Icons.arrow_upward : Icons.arrow_downward)
                              : Icons.unfold_more,
                          size: 16,
                          color: active ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(s.label,
                            style: TextStyle(
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? AppColors.primary : AppColors.textPrimary)),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        currentSort == null
                            ? Icons.swap_vert
                            : (currentSort!.ascending ? Icons.arrow_upward : Icons.arrow_downward),
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          currentSort == null ? 'Sort' : 'Sort · ${currentSort!.label}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opens the filter bottom sheet. Returns the edited [ListFilterState] on Apply,
/// null on dismiss. Pass [showPeriods]/[showDateRange] false to hide those
/// sections for screens that don't have a date dimension.
Future<ListFilterState?> showListFilterSheet(
  BuildContext context, {
  required ListFilterState initial,
  List<SelectFilter> selects = const [],
  List<FinancialYearOption> financialYears = const [],
  bool showPeriods = true,
  bool showDateRange = true,
  String title = 'Filters',
}) {
  final draft = initial.clone();
  return showModalBottomSheet<ListFilterState>(
    context: context,
    isScrollControlled: true,
    // Present on the root navigator so the sheet overlays the shell/bottom-nav
    // and isn't tied to the current tab's nested navigator lifecycle.
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> pickDate(bool from) async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: (from ? draft.dateFrom : draft.dateTo) ?? now,
              firstDate: DateTime(now.year - 6),
              lastDate: DateTime(now.year + 1),
            );
            if (picked != null) {
              setSheet(() {
                if (from) {
                  draft.dateFrom = picked;
                } else {
                  draft.dateTo = picked;
                }
                draft.period = null; // manual range overrides quick period
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.62,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (ctx, scrollCtrl) => Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
                    child: Row(
                      children: [
                        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setSheet(() => draft.clear()),
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      children: [
                        if (showPeriods) ...[
                          _sectionLabel('Quick Period'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: kQuickPeriods.map((p) {
                              final sel = draft.period == p.key;
                              return ChoiceChip(
                                label: Text(p.label),
                                selected: sel,
                                onSelected: (_) => setSheet(() {
                                  draft.period = sel ? null : p.key;
                                  draft.dateFrom = null;
                                  draft.dateTo = null;
                                }),
                                selectedColor: AppColors.primaryLight,
                                labelStyle: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  color: sel ? AppColors.primaryDark : AppColors.textSecondary,
                                ),
                                backgroundColor: AppColors.background,
                                side: BorderSide(color: sel ? AppColors.primary : AppColors.border),
                                showCheckmark: false,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (showDateRange) ...[
                          _sectionLabel('Custom Date Range'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _dateBox('From', draft.dateFrom, () => pickDate(true))),
                              const SizedBox(width: 10),
                              Expanded(child: _dateBox('To', draft.dateTo, () => pickDate(false))),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (financialYears.isNotEmpty) ...[
                          _sectionLabel('Financial Year'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: draft.financialYearId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            hint: const Text('All Years'),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('All Years')),
                              ...financialYears.map((fy) => DropdownMenuItem<String>(
                                    value: fy.id,
                                    child: Text(fy.label, overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) => setSheet(() => draft.financialYearId = v),
                          ),
                          const SizedBox(height: 16),
                        ],
                        for (final f in selects) ...[
                          _sectionLabel(f.label),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: draft.selects[f.key],
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            hint: Text(f.allLabel),
                            items: [
                              DropdownMenuItem<String>(value: null, child: Text(f.allLabel)),
                              ...f.options.map((o) => DropdownMenuItem<String>(value: o, child: Text(o, overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setSheet(() => draft.selects[f.key] = v),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, draft),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Apply${draft.activeCount > 0 ? ' (${draft.activeCount})' : ''}'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _sectionLabel(String text) => Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textSecondary),
    );

Widget _dateBox(String label, DateTime? value, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                Text(
                  value == null ? 'Any' : _ymd(value),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value == null ? AppColors.textMuted : AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

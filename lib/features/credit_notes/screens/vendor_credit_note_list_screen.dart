import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/credit_note_model.dart';
import '../../../widgets/common/list_controls.dart';
import '../providers/credit_note_providers.dart';

/// Vendor Credit Notes list — parity with the web report: rows show vendor, CN #,
/// source bill, date, reason and amount. Each note is always against one purchase.
///
/// The provider is a bare [FutureProvider] returning the full list, so search,
/// vendor/date filters and sort all run CLIENT-SIDE over the loaded list here.
class VendorCreditNoteListScreen extends ConsumerStatefulWidget {
  const VendorCreditNoteListScreen({super.key});
  @override
  ConsumerState<VendorCreditNoteListScreen> createState() => _VendorCreditNoteListScreenState();
}

class _VendorCreditNoteListScreenState extends ConsumerState<VendorCreditNoteListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _shortDate(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);

  /// Client-side date window: quick period (resolved) or manual from/to. A CN with
  /// no parseable date is excluded whenever a date filter is active.
  bool _inDateWindow(VendorCreditNote n) {
    final w = _filters.effectiveWindow;
    final from = w?.from ?? _filters.dateFrom;
    final to = w?.to ?? _filters.dateTo;
    if (from == null && to == null) return true;
    final d = DateTime.tryParse(n.creditNoteDate ?? '');
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (from != null && day.isBefore(DateTime(from.year, from.month, from.day))) return false;
    if (to != null && day.isAfter(DateTime(to.year, to.month, to.day))) return false;
    return true;
  }

  /// Search (CN# / vendor / purchase# / invoice#) + vendor select + date window + sort.
  List<VendorCreditNote> _visible(List<VendorCreditNote> all) {
    final q = _search.trim().toLowerCase();
    final vendor = _filters.select('vendor');
    var rows = all.where((n) {
      if (q.isNotEmpty) {
        final hay = [
          n.creditNoteNumber,
          n.vendorName,
          n.purchaseNumber ?? '',
          n.invoiceNumber ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (vendor != null && vendor.isNotEmpty && n.vendorName != vendor) return false;
      if (!_inDateWindow(n)) return false;
      return true;
    }).toList();
    final sort = _sort;
    if (sort != null) {
      rows = applySort(rows, sort, (n, key) {
        switch (key) {
          case 'date':
            return n.creditNoteDate;
          case 'amount':
            return n.totalAmount;
        }
        return null;
      });
    }
    return rows;
  }

  Future<void> _openFilters() async {
    final notes = ref.read(vendorCreditNoteListProvider).asData?.value ?? const <VendorCreditNote>[];
    final vendors = notes
        .map((n) => n.vendorName)
        .where((v) => v.isNotEmpty && v != '—')
        .toSet()
        .toList()
      ..sort();
    final result = await showListFilterSheet(
      context,
      initial: _filters,
      showPeriods: true,
      showDateRange: true,
      selects: [
        SelectFilter(key: 'vendor', label: 'Vendor', options: vendors),
      ],
    );
    if (result != null) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vendorCreditNoteListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vendor Credit Notes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/vendor-credit-notes/create');
          ref.invalidate(vendorCreditNoteListProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(
        children: [
          _searchField(),
          FilterSortButtons(
            activeFilterCount: _filters.activeCount,
            onFilterTap: _openFilters,
            sortOptions: const [SortSpec('date', 'Date'), SortSpec('amount', 'Amount')],
            currentSort: _sort,
            onSortChanged: (s) => setState(() => _sort = s),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
              data: (notes) {
                if (notes.isEmpty) return _empty();
                final visible = _visible(notes);
                return Column(
                  children: [
                    _summary(visible),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => ref.invalidate(vendorCreditNoteListProvider),
                        child: visible.isEmpty
                            ? _noMatch()
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) => _row(visible[i]),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search CN #, vendor, bill...',
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

  Widget _summary(List<VendorCreditNote> rows) {
    final total = rows.fold<double>(0, (a, n) => a + n.totalAmount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${rows.length} credit note${rows.length == 1 ? '' : 's'}  ·  ${CurrencyUtils.format(total)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _row(VendorCreditNote n) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(n.creditNoteNumber.isEmpty ? 'Credit note' : n.creditNoteNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                const SizedBox(width: 8),
                Text('· ${n.billLabel}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 4),
              Text(n.vendorName, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${_shortDate(n.creditNoteDate)}${(n.reason != null && n.reason!.isNotEmpty) ? '  ·  ${n.reason}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Text(CurrencyUtils.format(n.totalAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
      );

  Widget _empty() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.assignment_return_outlined, size: 46, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(child: Text('No vendor credit notes yet.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );

  Widget _noMatch() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.search_off, size: 46, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(child: Text('No credit notes match your filters.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );
}

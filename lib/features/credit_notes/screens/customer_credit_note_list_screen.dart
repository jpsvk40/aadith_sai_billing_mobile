import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/credit_note_model.dart';
import '../../../widgets/common/list_controls.dart';
import '../providers/credit_note_providers.dart';

/// Customer Credit Notes list — parity with the web page: subtitle, status filter
/// pills, and rows showing CN #, customer, date, reason, amount, status.
class CustomerCreditNoteListScreen extends ConsumerStatefulWidget {
  const CustomerCreditNoteListScreen({super.key});
  @override
  ConsumerState<CustomerCreditNoteListScreen> createState() => _CustomerCreditNoteListScreenState();
}

class _CustomerCreditNoteListScreenState extends ConsumerState<CustomerCreditNoteListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(customerCreditNoteListProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _shortDate(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);

  /// Client-side search (CN # / reason) + customer select filter + sort over the loaded list.
  List<CustomerCreditNote> _visible(List<CustomerCreditNote> all) {
    final q = _search.trim().toLowerCase();
    final cust = _filters.select('customer');
    var rows = all.where((n) {
      if (q.isNotEmpty) {
        final hay = '${n.creditNoteNumber} ${n.reason ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (cust != null && cust.isNotEmpty && (n.customerName ?? '') != cust) return false;
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

  Future<void> _openFilters(List<String> customerOptions) async {
    final result = await showListFilterSheet(
      context,
      initial: _filters,
      showPeriods: false,
      showDateRange: false,
      selects: [
        SelectFilter(key: 'customer', label: 'Customer', options: customerOptions),
      ],
    );
    if (result != null) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerCreditNoteListProvider);
    final filters = ['All', ...CustomerCreditNoteStatus.all];
    final customerOptions = state.notes
        .map((n) => n.customerName)
        .where((c) => c != null && c.isNotEmpty)
        .map((c) => c!)
        .toSet()
        .toList()
      ..sort();
    final visible = _visible(state.notes);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Credit Notes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/credit-notes/create');
          if (mounted) ref.read(customerCreditNoteListProvider.notifier).load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Credit Note'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Issue a credit against a sales return, rate difference or shortage — it applies to the customer\'s open invoices.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ),
          ),
          _searchField(),
          FilterSortButtons(
            activeFilterCount: _filters.activeCount,
            onFilterTap: () => _openFilters(customerOptions),
            sortOptions: const [SortSpec('date', 'Date'), SortSpec('amount', 'Amount')],
            currentSort: _sort,
            onSortChanged: (s) => setState(() => _sort = s),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final f = filters[i];
                final active = state.statusFilter == f;
                return InkWell(
                  onTap: () => ref.read(customerCreditNoteListProvider.notifier).setFilter(f),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.textPrimary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? AppColors.textPrimary : AppColors.border),
                    ),
                    child: Text(
                      f == 'All' ? 'All' : CustomerCreditNoteStatus.pretty(f),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _error(state.error!)
                    : state.notes.isEmpty
                        ? _empty()
                        : RefreshIndicator(
                            onRefresh: () => ref.read(customerCreditNoteListProvider.notifier).load(),
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
      ),
    );
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search credit note #, reason...',
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

  Widget _noMatch() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.search_off, size: 46, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(child: Text('No credit notes match your filters.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );

  Widget _row(CustomerCreditNote n) {
    final c = CustomerCreditNoteStatus.color(n.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(n.creditNoteNumber.isEmpty ? 'Credit note' : n.creditNoteNumber,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  _chip(CustomerCreditNoteStatus.pretty(n.status), c),
                ]),
                const SizedBox(height: 4),
                Text(n.customerName ?? '—', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${_shortDate(n.creditNoteDate)}${(n.reason != null && n.reason!.isNotEmpty) ? '  ·  ${n.reason}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyUtils.format(n.totalAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (n.balanceAmount > 0 && n.balanceAmount < n.totalAmount)
                Text('Bal ${CurrencyUtils.formatCompact(n.balanceAmount)}', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
      );

  Widget _empty() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.assignment_returned_outlined, size: 46, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(child: Text('No customer credit notes yet.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );

  Widget _error(String e) => ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
          const SizedBox(height: 12),
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
        ],
      );
}

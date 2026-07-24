import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/service_ticket_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../providers/service_providers.dart';

/// F2 — "Out at company" worklist: units currently at the manufacturer (RMA status SENT),
/// with an overdue flag when the expected-return date has passed. Tap → the ticket.
///
/// The list is loaded whole from the backend, so the overdue toggle, sort menu
/// and company filter all run client-side over the loaded rows.
class RmaOutstandingScreen extends ConsumerStatefulWidget {
  const RmaOutstandingScreen({super.key});

  @override
  ConsumerState<RmaOutstandingScreen> createState() => _RmaOutstandingScreenState();
}

class _RmaOutstandingScreenState extends ConsumerState<RmaOutstandingScreen> {
  bool _overdueOnly = false;
  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  /// Applies the overdue toggle + company filter + sort over the loaded rows.
  List<ServiceTicketRma> _visible(List<ServiceTicketRma> rows) {
    var list = rows.where((r) {
      if (_overdueOnly && !r.overdue) return false;
      final co = _filters.select('company');
      if (co != null && r.company != co) return false;
      return true;
    }).toList();
    if (_sort != null) {
      list = applySort<ServiceTicketRma>(list, _sort!, (r, key) {
        switch (key) {
          case 'daysOut':
            return r.daysOut;
          case 'expectedReturn':
            return r.expectedReturnAt;
          case 'company':
            return r.company.toLowerCase();
        }
        return null;
      });
    }
    return list;
  }

  Future<void> _openFilters(List<String> companies) async {
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      title: 'Filter RMAs',
      showPeriods: false,
      showDateRange: false,
      selects: [
        SelectFilter(key: 'company', label: 'Company', options: companies),
      ],
    );
    if (res != null) setState(() => _filters = res);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rmaOutstandingProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Out at Company')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(rmaOutstandingProvider)),
        data: (rmas) {
          if (rmas.isEmpty) {
            return const EmptyStateWidget(icon: Icons.local_shipping_outlined, message: 'Nothing out at the company. Units sent to a manufacturer for warranty replacement show here until received back.');
          }
          // Distinct company/vendor names from the loaded rows drive the filter.
          final companies = rmas.map((r) => r.company).where((c) => c.isNotEmpty && c != '—').toSet().toList()..sort();
          final list = _visible(rmas);
          final overdue = list.where((r) => r.overdue).length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('${list.length} out at company', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if (overdue > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text('$overdue overdue', style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 10),
                    FilterSortButtons(
                      padding: EdgeInsets.zero,
                      activeFilterCount: _filters.activeCount,
                      onFilterTap: () => _openFilters(companies),
                      sortOptions: const [
                        SortSpec('daysOut', 'Days out'), // desc — most days out first
                        SortSpec('expectedReturn', 'Expected return', ascending: true), // earliest first
                        SortSpec('company', 'Company', ascending: true), // A → Z
                      ],
                      currentSort: _sort,
                      onSortChanged: (s) => setState(() => _sort = s),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilterChip(
                        label: const Text('Overdue only'),
                        selected: _overdueOnly,
                        onSelected: (v) => setState(() => _overdueOnly = v),
                        avatar: Icon(Icons.error_outline, size: 16, color: _overdueOnly ? AppColors.danger : AppColors.textMuted),
                        showCheckmark: false,
                        selectedColor: AppColors.danger.withValues(alpha: 0.12),
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _overdueOnly ? FontWeight.w700 : FontWeight.w600,
                          color: _overdueOnly ? AppColors.danger : AppColors.textSecondary,
                        ),
                        side: BorderSide(color: _overdueOnly ? AppColors.danger : AppColors.border),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(rmaOutstandingProvider),
                  child: list.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
                          children: const [
                            EmptyStateWidget(icon: Icons.filter_alt_off_outlined, message: 'No units match these filters.'),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          children: [...list.map((r) => _card(context, r))],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, ServiceTicketRma r) {
    final chipColor = r.overdue ? AppColors.danger : (r.daysOut != null && r.daysOut! >= 4 ? AppColors.warning : AppColors.info);
    final chipText = r.overdue ? 'Overdue' : (r.daysOut != null ? '${r.daysOut}d out' : 'Sent');
    return InkWell(
      onTap: r.ticketId != null ? () => context.push('/service/tickets/${r.ticketId}') : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: r.overdue ? AppColors.danger.withValues(alpha: 0.55) : AppColors.border, width: r.overdue ? 1.4 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.rmaNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text([r.ticketDevice, r.ticketNumber].where((e) => (e ?? '').isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(chipText, style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.factory_outlined, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(r.company, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            if (r.expectedReturnAt != null)
              Text('Exp ${AppDateUtils.formatDisplay(r.expectedReturnAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}

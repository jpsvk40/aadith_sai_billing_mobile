import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_ticket_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/list_controls.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/service_providers.dart';
import '../service_status.dart';

/// Technician's assigned ticket queue (assignedTo=me). Doubles as the admin all-tickets list
/// when [adminMode] is true.
class MyTicketsScreen extends ConsumerStatefulWidget {
  final bool adminMode;
  const MyTicketsScreen({super.key, this.adminMode = false});
  @override
  ConsumerState<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends ConsumerState<MyTicketsScreen> {
  // Full status sheet (mirrors backend warranty FSM). Raw enum sent to the API; label() renders it nicely.
  static const _filters = [
    'All',
    'OPEN',
    'ASSIGNED',
    'DIAGNOSED',
    'AWAITING_PARTS',
    'AWAITING_APPROVAL',
    'IN_PROGRESS',
    'SENT_TO_COMPANY',
    'RECEIVED_FROM_COMPANY',
    'READY',
    'DELIVERED',
    'CLOSED',
    'CANCELLED',
  ];

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  ListFilterState _filter = ListFilterState();
  SortSpec? _sort;

  StateNotifierProvider<MyTicketsNotifier, MyTicketsState> get _provider =>
      widget.adminMode ? allTicketsProvider : myTicketsProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(_provider.notifier).load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(_provider.notifier).setSearch(v.trim());
      ref.read(_provider.notifier).load();
    });
  }

  /// Client-side customer filter + date sort over the already-loaded list.
  List<ServiceTicket> _applyClient(List<ServiceTicket> tickets) {
    var out = tickets;
    final cust = _filter.select('customer');
    if (cust != null && cust.isNotEmpty) {
      out = out.where((t) => t.customerName == cust).toList();
    }
    if (_sort != null) {
      out = applySort(out, _sort!, (t, key) => t.reportedAt);
    }
    return out;
  }

  Future<void> _openFilters(MyTicketsState state) async {
    final customers = state.tickets
        .map((t) => t.customerName)
        .where((n) => n.isNotEmpty && n != '—')
        .toSet()
        .toList()
      ..sort();
    final res = await showListFilterSheet(
      context,
      initial: _filter,
      showPeriods: false,
      showDateRange: false,
      title: 'Filter Tickets',
      selects: [SelectFilter(key: 'customer', label: 'Customer', options: customers)],
    );
    if (res != null) setState(() => _filter = res);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final isAdmin = widget.adminMode;
    final visible = _applyClient(state.tickets);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isAdmin ? 'Service Tickets' : 'My Tickets'),
        actions: [
          IconButton(
            tooltip: 'Warranty lookup',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.go('/service/warranty-lookup'),
          ),
          if (isAdmin)
            IconButton(icon: const Icon(Icons.add), onPressed: () => context.go('/service/tickets/create')),
        ],
      ),
      body: Column(
        children: [
          _searchField(),
          FilterSortButtons(
            activeFilterCount: _filter.activeCount,
            onFilterTap: () => _openFilters(state),
            sortOptions: const [SortSpec('date', 'Date')],
            currentSort: _sort,
            onSortChanged: (s) => setState(() => _sort = s),
          ),
          _statusFilter(state),
          Expanded(
            child: state.isLoading && state.tickets.isEmpty
                ? const LoadingIndicator()
                : state.error != null && state.tickets.isEmpty
                    ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(_provider.notifier).load())
                    : RefreshIndicator(
                        onRefresh: () => ref.read(_provider.notifier).load(),
                        child: visible.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 120),
                                EmptyStateWidget(message: 'No tickets here', icon: Icons.build_circle_outlined),
                              ])
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 4, bottom: 24),
                                itemCount: visible.length,
                                itemBuilder: (ctx, i) => _ticketCard(visible[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) {
          setState(() {}); // reflect the clear (×) affordance live
          _onSearchChanged(v);
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search ticket #, customer, device…',
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _statusFilter(MyTicketsState state) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final f = _filters[i];
          final selected = state.statusFilter == f;
          return ChoiceChip(
            label: Text(f == 'All' ? 'All' : ServiceStatus.label(f)),
            selected: selected,
            onSelected: (_) => ref.read(_provider.notifier).setStatus(f),
            selectedColor: AppColors.primaryLight,
            labelStyle: TextStyle(color: selected ? AppColors.primaryDark : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5),
          );
        },
      ),
    );
  }

  Widget _ticketCard(ServiceTicket t) {
    return AppCard(
      onTap: () => context.go('/service/tickets/${t.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.ticketNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              ServiceStatusChip(status: t.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (t.serviceItem?.label.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${t.serviceItem!.label}  ·  ${t.serviceItem!.serialNumber ?? ''}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 4),
          Text(t.reportedProblem, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _tag(ServiceStatus.serviceTypeLabel(t.serviceType), AppColors.textSecondary),
              const SizedBox(width: 8),
              _tag(t.priority, ServiceStatus.priorityColor(t.priority)),
              const Spacer(),
              if (t.slaBreached)
                const Row(children: [Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger), SizedBox(width: 3), Text('SLA', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700))]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

/// Thin wrapper so the router can mount the technician variant.
class TechnicianTicketsScreen extends ConsumerWidget {
  const TechnicianTicketsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defensive: a non-service user should never reach here (guards handle it), but keep it graceful.
    final user = ref.watch(authProvider).user;
    return MyTicketsScreen(adminMode: user?.isTechnician != true);
  }
}

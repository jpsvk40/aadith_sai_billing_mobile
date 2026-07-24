import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/order_model.dart';
import '../../../data/providers/financial_year_provider.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/status_badge.dart';
import '../providers/order_list_provider.dart';

const _orderOrange = Color(0xFFF59E0B);
const _orderPurple = Color(0xFF7C3AED);

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _searchController = TextEditingController();
  String? _selectedStatus;

  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  static const _sortOptions = <SortSpec>[
    SortSpec('date', 'Date'),
    SortSpec('amount', 'Amount'),
    SortSpec('customer', 'Customer'),
  ];

  final _statuses = ['All', 'New', 'In Production', 'Production Completed', 'Packed', 'Dispatched', 'Delivered', 'Cancelled', 'Void'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(orderListProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    ref.read(orderListProvider.notifier).load(
          status: _selectedStatus == 'All' ? null : _selectedStatus,
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
          dateFrom: _filters.dateFromParam,
          dateTo: _filters.dateToParam,
          financialYearId: _filters.financialYearId,
        );
  }

  Future<void> _openFilters() async {
    final loaded = ref.read(orderListProvider).orders;
    final createdByOptions = loaded
        .map((o) => o.createdByName)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final fyData = await ref.read(financialYearsProvider.future);
    if (!mounted) return;
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      financialYears: fyData.years,
      selects: [
        SelectFilter(key: 'createdBy', label: 'Created By', options: createdByOptions),
        const SelectFilter(key: 'orderType', label: 'Order Type', options: ['Short-Closed', 'Normal']),
      ],
    );
    if (res != null) {
      setState(() => _filters = res);
      _applyFilter();
    }
  }

  bool _isShortClosed(Order o) =>
      o.items.any((i) => i.confirmedQuantity != null && i.confirmedQuantity! < i.quantity);

  Comparable? _orderSortValue(Order o, String key) {
    switch (key) {
      case 'date':
        return o.createdAt;
      case 'amount':
        return o.totalAmount;
      case 'customer':
        return (o.customerName ?? '').toLowerCase();
    }
    return null;
  }

  List<Order> _visible(List<Order> orders) {
    var list = orders;
    final createdBy = _filters.select('createdBy');
    if (createdBy != null && createdBy.isNotEmpty) {
      list = list.where((o) => (o.createdByName ?? '') == createdBy).toList();
    }
    final orderType = _filters.select('orderType');
    if (orderType != null && orderType.isNotEmpty) {
      list = list.where((o) => orderType == 'Short-Closed' ? _isShortClosed(o) : !_isShortClosed(o)).toList();
    }
    if (_sort != null) {
      list = applySort(list, _sort!, _orderSortValue);
    }
    return list;
  }

  Widget _summaryCards(List<Order> orders) {
    final total = orders.length;
    final inProd = orders.where((o) => o.status == 'In Production').length;
    final delivered = orders.where((o) => o.status == 'Delivered').length;
    final value = orders.fold<double>(0, (a, o) => a + (o.totalAmount ?? 0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.3,
        children: [
          _summaryCard('TOTAL ORDERS', '$total', AppColors.primary, Icons.receipt_long_outlined),
          _summaryCard('IN PRODUCTION', '$inProd', _orderOrange, Icons.build_circle_outlined),
          _summaryCard('DELIVERED', '$delivered', AppColors.success, Icons.check_circle_outline),
          _summaryCard('TOTAL VALUE', CurrencyUtils.formatCompact(value), _orderPurple, Icons.account_balance_wallet_outlined),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.22)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 5),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(financialYearsProvider); // kick off + cache FY list for the filter sheet
    final state = ref.watch(orderListProvider);
    final visible = _visible(state.orders);

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          _summaryCards(visible),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search orders...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _applyFilter(),
            ),
          ),
          FilterSortButtons(
            activeFilterCount: _filters.activeCount,
            onFilterTap: _openFilters,
            sortOptions: _sortOptions,
            currentSort: _sort,
            onSortChanged: (s) => setState(() => _sort = s),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final status = _statuses[i];
                final isSelected = (status == 'All' && _selectedStatus == null) || status == _selectedStatus;
                return FilterChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedStatus = status == 'All' ? null : status);
                    _applyFilter();
                  },
                  selectedColor: AppColors.primaryLight,
                  checkmarkColor: AppColors.primary,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.isLoading && state.orders.isEmpty
                ? const LoadingIndicator()
                : state.error != null && state.orders.isEmpty
                    ? ErrorStateWidget(message: state.error!, onRetry: _applyFilter)
                    : visible.isEmpty
                        ? const EmptyStateWidget(message: 'No orders found', icon: Icons.receipt_long_outlined)
                        : RefreshIndicator(
                            onRefresh: () async => _applyFilter(),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: visible.length,
                              itemBuilder: (ctx, i) => _OrderTile(order: visible[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final dynamic order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: () => context.go('/orders/${order.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 6),
              if (order.customerName != null)
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(order.customerName!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              if (order.createdByName != null && order.createdByName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('By ${order.createdByName!}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        AppDateUtils.formatDisplay(order.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (order.totalAmount != null)
                    Text(
                      CurrencyUtils.format(order.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

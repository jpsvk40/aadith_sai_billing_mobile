import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class OrderListState {
  final List<Order> orders;
  final bool isLoading;
  final String? error;
  final String? statusFilter;
  final String? search;
  final String? dateFrom;
  final String? dateTo;
  final String? financialYearId;

  const OrderListState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter,
    this.search,
    this.dateFrom,
    this.dateTo,
    this.financialYearId,
  });

  OrderListState copyWith({List<Order>? orders, bool? isLoading, String? error, String? statusFilter, String? search, String? dateFrom, String? dateTo, String? financialYearId}) {
    return OrderListState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
      search: search ?? this.search,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      financialYearId: financialYearId ?? this.financialYearId,
    );
  }
}

class OrderListNotifier extends StateNotifier<OrderListState> {
  final OrderRepository _repo;
  OrderListNotifier(this._repo) : super(const OrderListState());

  Future<void> load({String? status, String? search, String? dateFrom, String? dateTo, String? financialYearId}) async {
    state = state.copyWith(isLoading: true, error: null, statusFilter: status, search: search, dateFrom: dateFrom, dateTo: dateTo, financialYearId: financialYearId);
    try {
      final orders = await _repo.getOrders(status: status, search: search, dateFrom: dateFrom, dateTo: dateTo, financialYearId: financialYearId);
      state = OrderListState(orders: orders, statusFilter: status, search: search, dateFrom: dateFrom, dateTo: dateTo, financialYearId: financialYearId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final orderListProvider = StateNotifierProvider<OrderListNotifier, OrderListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return OrderListNotifier(OrderRepository(client));
});

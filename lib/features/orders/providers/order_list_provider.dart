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

  const OrderListState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter,
    this.search,
  });

  OrderListState copyWith({List<Order>? orders, bool? isLoading, String? error, String? statusFilter, String? search}) {
    return OrderListState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
      search: search ?? this.search,
    );
  }
}

class OrderListNotifier extends StateNotifier<OrderListState> {
  final OrderRepository _repo;
  OrderListNotifier(this._repo) : super(const OrderListState());

  Future<void> load({String? status, String? search}) async {
    state = state.copyWith(isLoading: true, error: null, statusFilter: status, search: search);
    try {
      final orders = await _repo.getOrders(status: status, search: search);
      state = OrderListState(orders: orders, statusFilter: status, search: search);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final orderListProvider = StateNotifierProvider<OrderListNotifier, OrderListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return OrderListNotifier(OrderRepository(client));
});

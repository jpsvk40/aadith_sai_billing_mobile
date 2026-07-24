import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/order_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/dispatch_repository.dart';
import '../../../data/repositories/order_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// The two sources the dispatch queue can show, mirroring the web tabs:
/// - `packed`      → orders ready to dispatch (`/orders?status=Packed`)
/// - `dispatched`  → dispatch entries already Dispatched/Delivered (`/dispatch`)
class DispatchScope {
  static const packed = 'packed';
  static const dispatched = 'dispatched';
}

class DispatchQueueState {
  /// Both sources are mapped into ONE card shape so the screen renders them
  /// identically: `{ id, orderId, status, order:{orderNo, grandTotal,
  /// customer:{customerName, city, district}}, bagCount.., transporterName..,
  /// dispatchDate/updatedAt/orderDate }`.
  final List<Map<String, dynamic>> rows;
  final bool isLoading;
  final String? error;
  final String scope;

  const DispatchQueueState({
    this.rows = const [],
    this.isLoading = false,
    this.error,
    this.scope = DispatchScope.packed,
  });

  DispatchQueueState copyWith({
    List<Map<String, dynamic>>? rows,
    bool? isLoading,
    String? error,
    String? scope,
  }) {
    return DispatchQueueState(
      rows: rows ?? this.rows,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      scope: scope ?? this.scope,
    );
  }
}

class DispatchQueueNotifier extends StateNotifier<DispatchQueueState> {
  final DispatchRepository _dispatchRepo;
  final OrderRepository _orderRepo;
  DispatchQueueNotifier(this._dispatchRepo, this._orderRepo)
      : super(const DispatchQueueState());

  /// Loads the given [scope]. Dates are forwarded to the server: the Packed
  /// scope filters on `orderDate` server-side (orders endpoint); the Dispatched
  /// scope passes them too but the endpoint ignores them, so the screen filters
  /// that list client-side.
  Future<void> load({
    required String scope,
    String? dateFrom,
    String? dateTo,
  }) async {
    // Clear rows when switching source so the loader shows instead of briefly
    // rendering the previous scope's (differently-shaped) rows.
    final clear = scope != state.scope;
    state = state.copyWith(isLoading: true, error: null, scope: scope, rows: clear ? const [] : null);
    try {
      final List<Map<String, dynamic>> rows;
      if (scope == DispatchScope.packed) {
        final orders = await _orderRepo.getOrders(
          status: 'Packed',
          dateFrom: dateFrom,
          dateTo: dateTo,
          limit: 500,
        );
        rows = orders.map(_fromOrder).toList();
      } else {
        rows = await _dispatchRepo.getDispatchEntries(
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
      }
      state = DispatchQueueState(rows: rows, scope: scope);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Maps a Packed [Order] into the shared dispatch-card shape.
  Map<String, dynamic> _fromOrder(Order o) => {
        'id': o.id,
        'orderId': o.id,
        'status': o.status,
        'order': {
          'orderNo': o.orderNumber,
          'grandTotal': o.totalAmount,
          'customer': {'customerName': o.customerName},
        },
        'orderDate': o.createdAt?.toIso8601String(),
      };
}

final dispatchQueueProvider =
    StateNotifierProvider<DispatchQueueNotifier, DispatchQueueState>((ref) {
  final client = ApiClient.getInstance(
      onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return DispatchQueueNotifier(DispatchRepository(client), OrderRepository(client));
});

import '../network/api_client.dart';
import '../models/order_model.dart';
import '../../core/constants/api_constants.dart';

class OrderRepository {
  final ApiClient _client;
  OrderRepository(this._client);

  Future<List<Order>> getOrders({
    String? status,
    String? search,
    String? dateFrom,
    String? dateTo,
    String? financialYearId,
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _client.get(
      ApiConstants.orders,
      queryParams: {
        if (status != null) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
        if (financialYearId != null && financialYearId.isNotEmpty) 'financialYearId': financialYearId,
        'page': page,
        'limit': limit,
      },
    );
    final list = data is Map ? (data['orders'] ?? data['data'] ?? data) : data;
    if (list is List) {
      return list
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Order> getOrderDetail(String id) async {
    final data = await _client.get(ApiConstants.orderDetail(id));
    return Order.fromJson(data['order'] ?? data);
  }

  Future<Order> createOrder(Map<String, dynamic> orderData) async {
    final data = await _client.post(ApiConstants.orders, data: orderData);
    return Order.fromJson(data['order'] ?? data);
  }

  Future<Order> updateOrder(String id, Map<String, dynamic> orderData) async {
    final data = await _client.put(
      ApiConstants.orderDetail(id),
      data: orderData,
    );
    return Order.fromJson(data['order'] ?? data);
  }
}

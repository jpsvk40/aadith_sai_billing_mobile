import '../network/api_client.dart';
import '../models/customer_model.dart';
import '../../core/constants/api_constants.dart';

class CustomerRepository {
  final ApiClient _client;
  CustomerRepository(this._client);

  Future<List<Customer>> getCustomers({String? search}) async {
    final data = await _client.get(
      ApiConstants.customers,
      queryParams: (search != null && search.isNotEmpty) ? {'search': search} : null,
    );
    final list = data is Map ? (data['customers'] ?? data['data'] ?? data) : data;
    if (list is List) {
      return list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Customer-specific product prices: productId -> effective rate.
  Future<Map<String, double>> getProductPricing(String customerId) async {
    final data = await _client.get('${ApiConstants.customers}/$customerId/product-pricing');
    final rules = (data is Map ? data['rules'] : data) as List? ?? const [];
    final map = <String, double>{};
    for (final r in rules) {
      if (r is Map) {
        final pid = r['productId']?.toString();
        final rate = double.tryParse(r['effectiveRate']?.toString() ?? '');
        if (pid != null && rate != null) map[pid] = rate;
      }
    }
    return map;
  }
}

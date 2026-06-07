import '../network/api_client.dart';
import '../models/product_model.dart';
import '../../core/constants/api_constants.dart';

class ProductRepository {
  final ApiClient _client;
  ProductRepository(this._client);

  Future<List<Product>> getProducts() async {
    final data = await _client.get(ApiConstants.products);
    final list = data is Map ? (data['products'] ?? data['data'] ?? data) : data;
    if (list is List) {
      return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}

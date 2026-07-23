import '../network/api_client.dart';
import '../models/product_model.dart';
import '../../core/constants/api_constants.dart';

class ProductRepository {
  final ApiClient _client;
  ProductRepository(this._client);

  List<Map<String, dynamic>> _asList(dynamic data) {
    final list = data is Map ? (data['products'] ?? data['data'] ?? data) : data;
    if (list is List) return list.map((e) => e as Map<String, dynamic>).toList();
    return const [];
  }

  Future<List<Product>> getProducts() async {
    final data = await _client.get(ApiConstants.products);
    return _asList(data).map(Product.fromJson).toList();
  }

  /// Full product-master rows for the admin list (supports `?search=`).
  Future<List<ProductDetail>> getProductDetails({String? search}) async {
    final qp = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) qp['search'] = search.trim();
    final data = await _client.get('/api/products', queryParams: qp.isEmpty ? null : qp);
    return _asList(data).map(ProductDetail.fromJson).toList();
  }

  Future<ProductDetail> getProduct(String id) async {
    final data = await _client.get('/api/products/$id');
    return ProductDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<ProductDetail> createProduct(Map<String, dynamic> body) async {
    final data = await _client.post('/api/products', data: body);
    return ProductDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<ProductDetail> updateProduct(String id, Map<String, dynamic> body) async {
    final data = await _client.put('/api/products/$id', data: body);
    return ProductDetail.fromJson(data as Map<String, dynamic>);
  }

  /// Distinct category strings for the datalist / suggestions.
  Future<List<String>> getCategories() async {
    final data = await _client.get('/api/products/categories');
    final list = data is Map ? (data['categories'] ?? data['data'] ?? data) : data;
    if (list is List) {
      return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }
}

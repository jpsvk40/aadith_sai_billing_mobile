import '../network/api_client.dart';
import '../models/vendor_model.dart';
import '../../core/constants/api_constants.dart';

class VendorRepository {
  final ApiClient _client;
  VendorRepository(this._client);

  Future<List<Vendor>> getVendors({String? search}) async {
    final data = await _client.get(
      ApiConstants.vendors,
      queryParams: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = data is Map
        ? (data['vendors'] ?? data['data'] ?? data['items'] ?? const [])
        : data;
    if (list is List) {
      return list
          .map((e) => Vendor.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Vendor> createVendor({
    required String vendorName,
    String? gstin,
    String? phone,
  }) async {
    final data = await _client.post(ApiConstants.vendors, data: {
      'vendorName': vendorName,
      if (gstin != null && gstin.isNotEmpty) 'gstin': gstin,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return Vendor.fromJson((data is Map && data['vendor'] != null)
        ? data['vendor'] as Map<String, dynamic>
        : data as Map<String, dynamic>);
  }
}

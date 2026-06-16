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
    String? email,
    String? contactPerson,
    String? billingAddress,
    String? city,
    String? state,
    String? pincode,
    bool forceCreate = false,
  }) async {
    bool ok(String? v) => v != null && v.trim().isNotEmpty;
    final data = await _client.post(ApiConstants.vendors, data: {
      'vendorName': vendorName,
      // The server rejects a create that collides with an existing valid GSTIN unless
      // forceCreate is set. Pass it when the user has explicitly chosen to create anyway.
      if (forceCreate) 'forceCreate': true,
      if (ok(gstin)) 'gstin': gstin,
      if (ok(phone)) 'phone': phone,
      if (ok(email)) 'email': email,
      if (ok(contactPerson)) 'contactPerson': contactPerson,
      if (ok(billingAddress)) 'billingAddress': billingAddress,
      if (ok(city)) 'city': city,
      if (ok(state)) 'state': state,
      if (ok(pincode)) 'pincode': pincode,
    });
    return Vendor.fromJson((data is Map && data['vendor'] != null)
        ? data['vendor'] as Map<String, dynamic>
        : data as Map<String, dynamic>);
  }

  /// Mirrors the web duplicate check: returns candidate matches by GSTIN / name.
  /// Each entry has id, vendorCode, vendorName, gstin, isActive, reason, score.
  Future<List<Map<String, dynamic>>> checkDuplicate({
    required String vendorName,
    String? gstin,
  }) async {
    final data = await _client.post('${ApiConstants.vendors}/check-duplicate', data: {
      'vendorName': vendorName,
      if (gstin != null && gstin.isNotEmpty) 'gstin': gstin,
    });
    final list = data is Map ? (data['duplicates'] ?? const []) : const [];
    if (list is List) {
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
}

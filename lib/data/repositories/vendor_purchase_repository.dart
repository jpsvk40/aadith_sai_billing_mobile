import '../network/api_client.dart';
import '../models/vendor_purchase_model.dart';
import '../../core/constants/api_constants.dart';

class VendorPurchaseRepository {
  final ApiClient _client;
  VendorPurchaseRepository(this._client);

  Future<List<VendorPurchase>> getPurchases({int page = 1, int limit = 20}) async {
    final data = await _client.get(ApiConstants.vendorPurchases, queryParams: {
      'page': page,
      'limit': limit,
    });
    final list = data is Map
        ? (data['purchases'] ?? data['data'] ?? data['items'] ?? const [])
        : data;
    if (list is List) {
      return list
          .map((e) => VendorPurchase.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Header-level purchase entry. Pass scannedInvoiceUrl as a data: URL
  /// (the backend converts it to an R2 key automatically).
  Future<VendorPurchase> createPurchase({
    required String vendorId,
    required String purchaseDate,
    String? invoiceNumber,
    String? invoiceDate,
    required double totalAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    String? notes,
    String? scannedInvoiceUrl,
    bool fromScan = false,
  }) async {
    final data = await _client.post(ApiConstants.vendorPurchases, data: {
      'vendorId': vendorId,
      'purchaseDate': purchaseDate,
      if (invoiceNumber != null && invoiceNumber.isNotEmpty)
        'invoiceNumber': invoiceNumber,
      if (invoiceDate != null && invoiceDate.isNotEmpty) 'invoiceDate': invoiceDate,
      'totalAmount': totalAmount,
      if (cgstAmount != null) 'cgstAmount': cgstAmount,
      if (sgstAmount != null) 'sgstAmount': sgstAmount,
      if (igstAmount != null) 'igstAmount': igstAmount,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (scannedInvoiceUrl != null && scannedInvoiceUrl.isNotEmpty)
        'scannedInvoiceUrl': scannedInvoiceUrl,
      if (fromScan) 'scanSource': 'AI',
    });
    return VendorPurchase.fromJson((data is Map && data['purchase'] != null)
        ? data['purchase'] as Map<String, dynamic>
        : data as Map<String, dynamic>);
  }
}

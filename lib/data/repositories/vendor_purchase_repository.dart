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

  /// Purchase entry. When [items] is provided the backend auto-calculates the
  /// total from the lines (+ freight/misc/roundOff); otherwise pass [totalAmount].
  /// Pass scannedInvoiceUrl as a data: URL (the backend converts it to an R2 key).
  Future<VendorPurchase> createPurchase({
    required String vendorId,
    required String purchaseDate,
    String? invoiceNumber,
    String? invoiceDate,
    double? totalAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? freightCharges,
    double? miscCharges,
    double? roundOff,
    List<Map<String, dynamic>>? items,
    String? notes,
    String? scannedInvoiceUrl,
    bool fromScan = false,
  }) async {
    final hasItems = items != null && items.isNotEmpty;
    final data = await _client.post(ApiConstants.vendorPurchases, data: {
      'vendorId': vendorId,
      'purchaseDate': purchaseDate,
      if (invoiceNumber != null && invoiceNumber.isNotEmpty)
        'invoiceNumber': invoiceNumber,
      if (invoiceDate != null && invoiceDate.isNotEmpty) 'invoiceDate': invoiceDate,
      if (hasItems) 'items': items,
      if (!hasItems && totalAmount != null) 'totalAmount': totalAmount,
      if (cgstAmount != null) 'cgstAmount': cgstAmount,
      if (sgstAmount != null) 'sgstAmount': sgstAmount,
      if (igstAmount != null) 'igstAmount': igstAmount,
      if (freightCharges != null && freightCharges > 0) 'freightCharges': freightCharges,
      if (miscCharges != null && miscCharges > 0) 'miscCharges': miscCharges,
      if (roundOff != null && roundOff != 0) 'roundOff': roundOff,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (scannedInvoiceUrl != null && scannedInvoiceUrl.isNotEmpty)
        'scannedInvoiceUrl': scannedInvoiceUrl,
      if (fromScan) 'scanSource': 'AI',
    });
    return VendorPurchase.fromJson((data is Map && data['purchase'] != null)
        ? data['purchase'] as Map<String, dynamic>
        : data as Map<String, dynamic>);
  }

  /// Reference pricing for a product (+ optional vendor): current selling price,
  /// last price from this vendor, and last price from any vendor.
  Future<Map<String, dynamic>?> priceHint({required String productId, String? vendorId}) async {
    try {
      final data = await _client.get(ApiConstants.vendorPurchasePriceHint, queryParams: {
        'productId': productId,
        if (vendorId != null) 'vendorId': vendorId,
      });
      return data is Map ? data.cast<String, dynamic>() : null;
    } catch (_) {
      return null; // hints are best-effort
    }
  }
}

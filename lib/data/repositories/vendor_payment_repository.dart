import '../network/api_client.dart';
import '../models/vendor_payment_model.dart';
import '../../core/constants/api_constants.dart';

/// Vendor payments — the merged list (single + bulk), the per-vendor ledger, and
/// the two record paths (single-bill and bulk FIFO). Payment endpoints are auth-only
/// on the server; the mobile route is gated `vendor_purchases`.
class VendorPaymentRepository {
  final ApiClient _client;
  VendorPaymentRepository(this._client);

  Future<List<VendorPaymentRow>> getPayments({String? vendorId, String? period}) async {
    final qp = <String, dynamic>{};
    if (vendorId != null && vendorId.isNotEmpty) qp['vendorId'] = vendorId;
    if (period != null && period.isNotEmpty) qp['period'] = period;
    final data = await _client.get(ApiConstants.vendorPayments, queryParams: qp.isEmpty ? null : qp);
    final list = data is Map ? (data['payments'] ?? data['data'] ?? data) : data;
    if (list is List) {
      return list.map((e) => VendorPaymentRow.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  Future<VendorLedger> getLedger(String vendorId) async {
    final data = await _client.get(ApiConstants.vendorLedger(vendorId));
    return VendorLedger.fromJson(data as Map<String, dynamic>);
  }

  /// Bulk FIFO payment. `amount` is a lump sum; the server allocates oldest-first.
  /// Optional `selectedPurchaseIds` restricts the pool. Excess → vendor credit.
  Future<Map<String, dynamic>> recordBulkPayment({
    required String vendorId,
    required String paymentDate,
    required double amount,
    required String paymentMode,
    String? referenceNo,
    String? remarks,
    bool applyCredit = false,
    List<int>? selectedPurchaseIds,
  }) async {
    final data = await _client.post(ApiConstants.vendorLedgerBulkPayment(vendorId), data: {
      'paymentDate': paymentDate,
      'amount': amount,
      'paymentMode': paymentMode,
      if (referenceNo != null && referenceNo.isNotEmpty) 'referenceNo': referenceNo,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      if (applyCredit) 'applyCredit': true,
      if (selectedPurchaseIds != null && selectedPurchaseIds.isNotEmpty) 'selectedPurchaseIds': selectedPurchaseIds,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Single-bill payment (capped at that bill's outstanding). Sends the vendor email + GL post.
  Future<Map<String, dynamic>> recordSinglePayment({
    required int vendorPurchaseId,
    required String paymentDate,
    required double amount,
    required String paymentMode,
    String? referenceNo,
    String? remarks,
  }) async {
    final data = await _client.post(ApiConstants.vendorPayments, data: {
      'vendorPurchaseId': vendorPurchaseId,
      'paymentDate': paymentDate,
      'amount': amount,
      'paymentMode': paymentMode,
      if (referenceNo != null && referenceNo.isNotEmpty) 'referenceNo': referenceNo,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> applyCredit(String vendorId) async {
    final data = await _client.post(ApiConstants.vendorLedgerApplyCredit(vendorId), data: const {});
    return (data as Map).cast<String, dynamic>();
  }
}

import '../network/api_client.dart';
import '../models/payment_model.dart';
import '../../core/constants/api_constants.dart';

class PaymentRepository {
  final ApiClient _client;
  PaymentRepository(this._client);

  Future<List<Payment>> getPayments({
    String? approvalStatus,
    String? period,
    String? dateFrom,
    String? dateTo,
    String? financialYearId,
  }) async {
    final qp = <String, dynamic>{};
    if (approvalStatus != null && approvalStatus != 'All') qp['approvalStatus'] = approvalStatus;
    if (period != null && period.isNotEmpty) qp['period'] = period;
    if (dateFrom != null && dateFrom.isNotEmpty) qp['dateFrom'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) qp['dateTo'] = dateTo;
    if (financialYearId != null && financialYearId.isNotEmpty) qp['financialYearId'] = financialYearId;
    final data = await _client.get(ApiConstants.payments, queryParams: qp.isEmpty ? null : qp);
    final list = data is Map ? (data['payments'] ?? data['data'] ?? data) : data;
    if (list is List) {
      return list.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Payment> recordPayment(Map<String, dynamic> paymentData) async {
    final data = await _client.post(ApiConstants.payments, data: paymentData);
    return Payment.fromJson(data['payment'] ?? data);
  }

  Future<void> approvePayment(String id) async {
    await _client.post('${ApiConstants.payments}/$id/approve', data: {});
  }

  Future<void> rejectPayment(String id, {String? remarks}) async {
    await _client.post('${ApiConstants.payments}/$id/reject', data: {'approvalRemarks': remarks ?? ''});
  }
}

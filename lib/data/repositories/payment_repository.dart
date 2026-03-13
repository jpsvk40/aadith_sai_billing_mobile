import '../network/api_client.dart';
import '../models/payment_model.dart';
import '../../core/constants/api_constants.dart';

class PaymentRepository {
  final ApiClient _client;
  PaymentRepository(this._client);

  Future<List<Payment>> getPayments({int page = 1, int limit = 20}) async {
    final data = await _client.get(ApiConstants.payments, queryParams: {
      'page': page,
      'limit': limit,
    });
    final list = data['payments'] ?? data['data'] ?? data;
    if (list is List) {
      return list.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Payment> recordPayment(Map<String, dynamic> paymentData) async {
    final data = await _client.post(ApiConstants.payments, data: paymentData);
    return Payment.fromJson(data['payment'] ?? data);
  }
}

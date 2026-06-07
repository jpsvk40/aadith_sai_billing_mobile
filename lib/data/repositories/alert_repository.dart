import '../network/api_client.dart';
import '../models/alert_model.dart';
import '../../core/constants/api_constants.dart';

class AlertRepository {
  final ApiClient _client;
  AlertRepository(this._client);

  Future<List<Alert>> getAlerts({String? status, String? alertType}) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (alertType != null && alertType.isNotEmpty) qp['alertType'] = alertType;
    final data = await _client.get(ApiConstants.alerts, queryParams: qp.isEmpty ? null : qp);
    final list = data is Map ? (data['alerts'] ?? data['data'] ?? data) : data;
    if (list is List) {
      return list.map((e) => Alert.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getSummary() async {
    final data = await _client.get('${ApiConstants.alerts}/summary');
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<void> markAsRead(String id) async {
    await _client.patch(ApiConstants.markAlertRead(id));
  }

  Future<void> acknowledge(String id) async {
    await _client.patch('${ApiConstants.alerts}/$id/acknowledge');
  }

  Future<void> resolve(String id) async {
    await _client.patch('${ApiConstants.alerts}/$id/resolve');
  }

  // Approve/Reject the payment linked to a payment_received alert (relatedId = paymentId).
  // The backend auto-resolves the alert on success.
  Future<void> approvePayment(String paymentId) async {
    await _client.post('${ApiConstants.payments}/$paymentId/approve', data: {});
  }

  Future<void> rejectPayment(String paymentId, String? remarks) async {
    await _client.post('${ApiConstants.payments}/$paymentId/reject', data: {'approvalRemarks': remarks ?? ''});
  }
}

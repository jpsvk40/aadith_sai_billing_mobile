import '../network/api_client.dart';
import '../models/alert_model.dart';
import '../../core/constants/api_constants.dart';

class AlertRepository {
  final ApiClient _client;
  AlertRepository(this._client);

  Future<List<Alert>> getAlerts({int page = 1, int limit = 30}) async {
    final data = await _client.get(ApiConstants.alerts, queryParams: {
      'page': page,
      'limit': limit,
    });
    final list = data['alerts'] ?? data['data'] ?? data;
    if (list is List) {
      return list.map((e) => Alert.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> markAsRead(String id) async {
    await _client.patch(ApiConstants.markAlertRead(id));
  }
}

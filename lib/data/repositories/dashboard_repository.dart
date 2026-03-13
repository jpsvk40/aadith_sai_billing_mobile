import '../network/api_client.dart';
import '../models/dashboard_model.dart';
import '../../core/constants/api_constants.dart';

class DashboardRepository {
  final ApiClient _client;
  DashboardRepository(this._client);

  Future<DashboardStats> getDashboard() async {
    try {
      final data = await _client.get(ApiConstants.dashboardEnhanced);
      return DashboardStats.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      final data = await _client.get(ApiConstants.dashboard);
      return DashboardStats.fromJson(data as Map<String, dynamic>);
    }
  }
}

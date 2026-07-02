import '../network/api_client.dart';
import '../models/dashboard_model.dart';
import '../models/command_center_model.dart';
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

  // ── Executive Command Center (mirrors the web Command Center) ──
  Future<MoneyBand> getMoneyBand() async {
    final data = await _client.get(ApiConstants.moneyBand);
    return MoneyBand.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<ActionCenter> getActionCenter({bool mine = false}) async {
    final data = await _client.get(mine ? ApiConstants.actionCenterMine : ApiConstants.actionCenter);
    return ActionCenter.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<ProjectsSummary> getProjectsSummary() async {
    final data = await _client.get(ApiConstants.projectsSummary);
    return ProjectsSummary.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<MachinerySummary> getMachinerySummary() async {
    final data = await _client.get(ApiConstants.machinerySummary);
    return MachinerySummary.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<TendersSummary> getTendersSummary() async {
    final data = await _client.get(ApiConstants.tendersSummary);
    return TendersSummary.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<MyWork> getMyWork() async {
    final data = await _client.get(ApiConstants.myWork);
    return MyWork.fromJson(data is Map<String, dynamic> ? data : const {});
  }
}

import '../network/api_client.dart';
import '../models/platform_dashboard_model.dart';
import '../models/platform_company_model.dart';
import '../../core/constants/api_constants.dart';

/// Data access for the Super Admin (platform operator) surfaces. Every endpoint here
/// is gated to `role == 'super_admin'` on the backend (`authorize('super_admin')`).
class SuperAdminRepository {
  final ApiClient _client;
  SuperAdminRepository(this._client);

  /// Platform-wide operations dashboard: totals, status/market mix, action queue,
  /// recent registrations, expiring trials/subs, and the latest activity trail.
  Future<PlatformDashboard> getDashboard() async {
    final data = await _client.get(ApiConstants.platformDashboard);
    return PlatformDashboard.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  /// Every tenant company (newest first). Search/filter is applied client-side.
  Future<List<PlatformCompany>> getCompanies() async {
    final data = await _client.get(ApiConstants.companies);
    final list = (data as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => PlatformCompany.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// A single company with its full user roster + settings.
  Future<PlatformCompany> getCompany(int id) async {
    final data = await _client.get(ApiConstants.companyDetail(id));
    return PlatformCompany.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  // ─── Lifecycle actions (all POST unless noted) ───

  Future<void> approveTrial(int id) =>
      _client.post(ApiConstants.companyAction(id, 'approve-trial'));

  Future<void> extendTrial(int id, {int extraDays = 30}) =>
      _client.post(ApiConstants.companyAction(id, 'extend-trial'), data: {'extraDays': extraDays});

  Future<void> activateSubscription(int id, {int durationDays = 365}) =>
      _client.post(ApiConstants.companyAction(id, 'activate-subscription'), data: {'durationDays': durationDays});

  Future<void> suspend(int id) =>
      _client.post(ApiConstants.companyAction(id, 'suspend'));

  Future<void> cancelSubscription(int id) =>
      _client.post(ApiConstants.companyAction(id, 'cancel-subscription'));

  Future<void> resetAdminPassword(int id) =>
      _client.post(ApiConstants.companyAction(id, 'reset-admin-password'));

  Future<void> unlockAdminLogin(int id) =>
      _client.post(ApiConstants.companyAction(id, 'unlock-admin-login'));

  Future<void> updateAdminEmail(int id, String email) =>
      _client.post(ApiConstants.companyAction(id, 'update-admin-email'), data: {'email': email});

  /// Change the packaging edition (billing | billing_books | erp).
  Future<void> setEdition(int id, String edition) =>
      _client.put('${ApiConstants.companyDetail(id)}/edition', data: {'edition': edition});
}

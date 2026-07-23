import '../network/api_client.dart';
import '../models/app_user_model.dart';

/// User / RBAC-lite admin API (admin-only on the server — `authorize('admin')`).
/// Endpoint paths are inline strings (this feature is small and self-contained; no
/// need to grow api_constants.dart for it).
class UserAdminRepository {
  final ApiClient _client;
  UserAdminRepository(this._client);

  /// GET /api/users — the server returns a WRAPPED `{ users:[...], meta:{...} }`, but
  /// we defensively also accept a bare array (older/edge responses).
  Future<(List<AppUser>, UserMeta)> listUsers() async {
    final data = await _client.get('/api/users');

    if (data is List) {
      final users = data
          .map((e) => AppUser.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      final active = users.where((u) => u.isActive).length;
      return (users, UserMeta.fromJson(const {}, fallbackActive: active));
    }

    final map = (data as Map).cast<String, dynamic>();
    final rawUsers = (map['users'] as List?) ?? const [];
    final users = rawUsers
        .map((e) => AppUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final meta = UserMeta.fromJson(
      (map['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
      fallbackActive: users.where((u) => u.isActive).length,
    );
    return (users, meta);
  }

  /// GET /api/catalog/access — module/role vocabulary that drives the toggles.
  Future<AccessCatalog> getAccessCatalog() async {
    final data = await _client.get('/api/catalog/access');
    return AccessCatalog.fromJson((data as Map).cast<String, dynamic>());
  }

  /// POST /api/users — admin sets the password directly (no email invite).
  Future<AppUser> createUser(Map<String, dynamic> body) async {
    final data = await _client.post('/api/users', data: body);
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  /// PUT /api/users/:id — every field optional (name/role/modules/isActive/aiAssistantAccess).
  /// Pass `modules: null` (or '') to clear a user's grant → inherit all company modules.
  Future<AppUser> updateUser(int id, Map<String, dynamic> body) async {
    final data = await _client.put('/api/users/$id', data: body);
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  /// POST /api/users/:id/reset-password — returns a one-time temp password (shown once).
  Future<String> resetPassword(int id) async {
    final data = await _client.post('/api/users/$id/reset-password', data: const {});
    return (data as Map)['tempPassword']?.toString() ?? '';
  }

  /// GET /api/users/available-reps?role= — unlinked reps to attach to a rep-based user.
  Future<List<RepOption>> availableReps(String role) async {
    final data = await _client.get('/api/users/available-reps', queryParams: {'role': role});
    final list = data is List ? data : const [];
    return list
        .map((e) => RepOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

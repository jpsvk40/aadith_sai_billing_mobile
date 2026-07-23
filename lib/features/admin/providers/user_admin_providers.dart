import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/app_user_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/user_admin_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Shared API client wired to log out on 401 (same pattern as the other feature providers).
final userAdminRepositoryProvider = Provider<UserAdminRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return UserAdminRepository(client);
});

/// The company user list + seat meta. Invalidate to refresh after create/edit/reset/toggle.
final usersProvider = FutureProvider<(List<AppUser>, UserMeta)>((ref) async {
  return ref.watch(userAdminRepositoryProvider).listUsers();
});

/// The module/role vocabulary that drives the module toggles in the form.
final accessCatalogProvider = FutureProvider<AccessCatalog>((ref) async {
  return ref.watch(userAdminRepositoryProvider).getAccessCatalog();
});

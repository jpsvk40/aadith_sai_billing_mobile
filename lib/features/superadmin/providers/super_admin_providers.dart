import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/super_admin_repository.dart';
import '../../../data/models/platform_dashboard_model.dart';
import '../../../data/models/platform_company_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Shared repository (one ApiClient, wired to the app's logout-on-401).
final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return SuperAdminRepository(client);
});

/// Control Tower payload. autoDispose so a fresh pull happens each visit;
/// `ref.invalidate` re-fetches after an action.
final platformDashboardProvider = FutureProvider.autoDispose<PlatformDashboard>((ref) async {
  return ref.read(superAdminRepositoryProvider).getDashboard();
});

/// Full company list (newest first). Screens filter/search/sort client-side.
final companiesProvider = FutureProvider.autoDispose<List<PlatformCompany>>((ref) async {
  return ref.read(superAdminRepositoryProvider).getCompanies();
});

/// A single company's detail (roster + lifecycle dates).
final companyDetailProvider =
    FutureProvider.autoDispose.family<PlatformCompany, int>((ref, id) async {
  return ref.read(superAdminRepositoryProvider).getCompany(id);
});

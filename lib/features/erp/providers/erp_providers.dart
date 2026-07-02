import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/erp_list_models.dart';
import '../../../data/repositories/erp_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

final erpRepositoryProvider = Provider<ErpRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return ErpRepository(client);
});

final projectsListProvider = FutureProvider.autoDispose<List<Project>>((ref) => ref.watch(erpRepositoryProvider).getProjects());
final machineryListProvider = FutureProvider.autoDispose<List<Machine>>((ref) => ref.watch(erpRepositoryProvider).getMachines());
final tendersListProvider = FutureProvider.autoDispose<List<Tender>>((ref) => ref.watch(erpRepositoryProvider).getTenders());

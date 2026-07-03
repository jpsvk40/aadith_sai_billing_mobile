import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/machine_detail_models.dart';
import '../../../data/repositories/machinery_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

final machineryRepositoryProvider = Provider<MachineryRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return MachineryRepository(client);
});

/// Machine detail (operator: assigned machines only — backend enforced).
final machineDetailProvider = FutureProvider.autoDispose.family<MachineDetail, int>(
  (ref, id) => ref.watch(machineryRepositoryProvider).getMachine(id),
);

/// "My machines" summary for the operator home (backend scopes by role).
final machinerySummaryProvider = FutureProvider.autoDispose<MachineryMineSummary>(
  (ref) => ref.watch(machineryRepositoryProvider).getSummary(),
);

/// Transfers register — the field home surfaces PENDING/IN_TRANSIT ones to receive.
final machineTransfersProvider = FutureProvider.autoDispose<List<MachineTransferLite>>(
  (ref) => ref.watch(machineryRepositoryProvider).getTransfers(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/commission_model.dart';
import '../../../data/repositories/commission_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class CommissionState {
  final List<Commission> commissions;
  final CommissionSummary? summary;
  final bool isLoading;
  final String? error;

  const CommissionState({this.commissions = const [], this.summary, this.isLoading = false, this.error});

  CommissionState copyWith({List<Commission>? commissions, CommissionSummary? summary, bool? isLoading, String? error}) {
    return CommissionState(commissions: commissions ?? this.commissions, summary: summary ?? this.summary, isLoading: isLoading ?? this.isLoading, error: error);
  }
}

class CommissionNotifier extends StateNotifier<CommissionState> {
  final CommissionRepository _repo;
  CommissionNotifier(this._repo) : super(const CommissionState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getCommissions(),
        _repo.getSummary().catchError((_) => CommissionSummary(totalSales: 0, totalCommission: 0, pendingCommission: 0, paidCommission: 0, totalInvoices: 0)),
      ]);
      state = CommissionState(
        commissions: results[0] as List<Commission>,
        summary: results[1] as CommissionSummary,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final commissionProvider = StateNotifierProvider<CommissionNotifier, CommissionState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return CommissionNotifier(CommissionRepository(client));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardState {
  final DashboardStats? stats;
  final bool isLoading;
  final String? error;

  const DashboardState({this.stats, this.isLoading = false, this.error});

  DashboardState copyWith({DashboardStats? stats, bool? isLoading, String? error}) {
    return DashboardState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardRepository _repo;

  DashboardNotifier(this._repo) : super(const DashboardState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final stats = await _repo.getDashboard();
      state = DashboardState(stats: stats, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () {
    ref.read(authProvider.notifier).logout();
  });
  return DashboardNotifier(DashboardRepository(client));
});

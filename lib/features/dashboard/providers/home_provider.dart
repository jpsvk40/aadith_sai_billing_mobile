import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/mobile_home_model.dart';
import '../../../data/repositories/home_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class HomeState {
  final HomeOverview? overview;
  final bool isLoading;
  final String? error;

  const HomeState({this.overview, this.isLoading = false, this.error});

  HomeState copyWith({HomeOverview? overview, bool? isLoading, String? error}) {
    return HomeState(
      overview: overview ?? this.overview,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repo;
  HomeNotifier(this._repo) : super(const HomeState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final overview = await _repo.getHome();
      state = HomeState(overview: overview);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  final client = ApiClient.getInstance(
      onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return HomeNotifier(HomeRepository(client));
});

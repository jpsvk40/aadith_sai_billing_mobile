import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/stocktake_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/stocktake_repository.dart';
import '../../auth/providers/auth_provider.dart';

final stocktakeRepositoryProvider = Provider<StocktakeRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return StocktakeRepository(client);
});

class StocktakeListState {
  final List<Stocktake> stocktakes;
  final bool isLoading;
  final String? error;
  final String statusFilter; // 'All' | one of StocktakeStatus.all

  const StocktakeListState({
    this.stocktakes = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter = 'All',
  });

  StocktakeListState copyWith({List<Stocktake>? stocktakes, bool? isLoading, String? error, String? statusFilter}) =>
      StocktakeListState(
        stocktakes: stocktakes ?? this.stocktakes,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        statusFilter: statusFilter ?? this.statusFilter,
      );
}

class StocktakeListNotifier extends StateNotifier<StocktakeListState> {
  final StocktakeRepository _repo;
  StocktakeListNotifier(this._repo) : super(const StocktakeListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _repo.getStocktakes(status: state.statusFilter);
      state = state.copyWith(stocktakes: rows, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setFilter(String status) async {
    state = state.copyWith(statusFilter: status);
    await load();
  }
}

final stocktakeListProvider =
    StateNotifierProvider<StocktakeListNotifier, StocktakeListState>((ref) => StocktakeListNotifier(ref.watch(stocktakeRepositoryProvider)));

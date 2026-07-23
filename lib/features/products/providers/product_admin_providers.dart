import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/product_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/product_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Product-master admin repo + list state (search). Route module-gated `products`.
final productAdminRepositoryProvider = Provider<ProductRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return ProductRepository(client);
});

class ProductListState {
  final List<ProductDetail> products;
  final bool isLoading;
  final String? error;
  final String search;

  const ProductListState({
    this.products = const [],
    this.isLoading = false,
    this.error,
    this.search = '',
  });

  ProductListState copyWith({List<ProductDetail>? products, bool? isLoading, String? error, String? search}) =>
      ProductListState(
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        search: search ?? this.search,
      );
}

class ProductListNotifier extends StateNotifier<ProductListState> {
  final ProductRepository _repo;
  ProductListNotifier(this._repo) : super(const ProductListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _repo.getProductDetails(search: state.search);
      state = state.copyWith(products: rows, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSearch(String q) async {
    state = state.copyWith(search: q);
    await load();
  }
}

final productListProvider =
    StateNotifierProvider<ProductListNotifier, ProductListState>((ref) => ProductListNotifier(ref.watch(productAdminRepositoryProvider)));

/// Distinct categories for the create/edit form suggestions.
final productCategoriesProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(productAdminRepositoryProvider).getCategories();
});

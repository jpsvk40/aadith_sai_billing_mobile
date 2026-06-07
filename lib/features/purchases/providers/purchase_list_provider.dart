import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/vendor_purchase_model.dart';
import '../../../data/repositories/vendor_purchase_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class PurchaseListState {
  final List<VendorPurchase> purchases;
  final bool isLoading;
  final String? error;
  final String statusFilter; // All | PENDING | PARTIALLY_PAID | PAID | CANCELLED
  final String search;

  const PurchaseListState({
    this.purchases = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter = 'All',
    this.search = '',
  });

  PurchaseListState copyWith({
    List<VendorPurchase>? purchases,
    bool? isLoading,
    String? error,
    String? statusFilter,
    String? search,
  }) {
    return PurchaseListState(
      purchases: purchases ?? this.purchases,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
      search: search ?? this.search,
    );
  }
}

class PurchaseListNotifier extends StateNotifier<PurchaseListState> {
  final VendorPurchaseRepository _repo;
  PurchaseListNotifier(this._repo) : super(const PurchaseListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final purchases = await _repo.getPurchases(limit: 200);
      state = state.copyWith(purchases: purchases, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setStatus(String s) => state = state.copyWith(statusFilter: s);
  void setSearch(String s) => state = state.copyWith(search: s);
}

final purchaseListProvider = StateNotifierProvider<PurchaseListNotifier, PurchaseListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return PurchaseListNotifier(VendorPurchaseRepository(client));
});

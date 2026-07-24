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
  final String? dateFrom; // yyyy-MM-dd (server filter)
  final String? dateTo; // yyyy-MM-dd (server filter)
  final String? financialYearId; // server filter

  const PurchaseListState({
    this.purchases = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter = 'All',
    this.search = '',
    this.dateFrom,
    this.dateTo,
    this.financialYearId,
  });

  PurchaseListState copyWith({
    List<VendorPurchase>? purchases,
    bool? isLoading,
    String? error,
    String? statusFilter,
    String? search,
    String? dateFrom,
    String? dateTo,
    bool hasDates = false, // when true, dateFrom/dateTo/financialYearId are applied even if null
    String? financialYearId,
  }) {
    return PurchaseListState(
      purchases: purchases ?? this.purchases,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
      search: search ?? this.search,
      dateFrom: hasDates ? dateFrom : this.dateFrom,
      dateTo: hasDates ? dateTo : this.dateTo,
      financialYearId: hasDates ? financialYearId : (financialYearId ?? this.financialYearId),
    );
  }
}

class PurchaseListNotifier extends StateNotifier<PurchaseListState> {
  final VendorPurchaseRepository _repo;
  PurchaseListNotifier(this._repo) : super(const PurchaseListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      // Status + search are applied SERVER-side (was a client-only filter over the
      // first 200 rows — silent truncation). limit=500 is a safety net.
      final purchases = await _repo.getPurchases(
        limit: 500,
        status: state.statusFilter == 'All' ? null : state.statusFilter,
        search: state.search.trim().isEmpty ? null : state.search.trim(),
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        financialYearId: state.financialYearId,
      );
      state = state.copyWith(purchases: purchases, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setStatus(String s) async {
    state = state.copyWith(statusFilter: s);
    await load();
  }

  Future<void> setSearch(String s) async {
    state = state.copyWith(search: s);
    await load();
  }

  Future<void> setDateRange(String? from, String? to, {String? financialYearId}) async {
    state = state.copyWith(dateFrom: from, dateTo: to, financialYearId: financialYearId, hasDates: true);
    await load();
  }
}

final purchaseListProvider = StateNotifierProvider<PurchaseListNotifier, PurchaseListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return PurchaseListNotifier(VendorPurchaseRepository(client));
});

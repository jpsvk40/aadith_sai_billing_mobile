import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/inventory_transaction_model.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Feature-local endpoint — the posted stock-entry history list.
/// (Mirrors the web `GET /api/inventory-transactions`.)
const _invTxns = '/api/inventory-transactions';

class StockEntriesState {
  final List<InventoryTransaction> entries;
  final bool isLoading;
  final String? error;

  const StockEntriesState({this.entries = const [], this.isLoading = false, this.error});

  StockEntriesState copyWith({List<InventoryTransaction>? entries, bool? isLoading, String? error}) {
    return StockEntriesState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StockEntriesNotifier extends StateNotifier<StockEntriesState> {
  final ApiClient _client;
  StockEntriesNotifier(this._client) : super(const StockEntriesState());

  /// Server-side filters supported by the endpoint: `financialYearId`,
  /// `dateFrom`, `dateTo`. Entry-type, search and sort are applied client-side
  /// in the screen. Results come back newest-first (txnDate desc), capped at 200.
  Future<void> load({String? financialYearId, String? dateFrom, String? dateTo}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _client.get(_invTxns, queryParams: {
        if (financialYearId != null && financialYearId.isNotEmpty) 'financialYearId': financialYearId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      });
      final list = (data is List ? data : const [])
          .whereType<Map>()
          .map((e) => InventoryTransaction.fromJson(e.cast<String, dynamic>()))
          .toList();
      state = StockEntriesState(entries: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final stockEntriesProvider = StateNotifierProvider<StockEntriesNotifier, StockEntriesState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return StockEntriesNotifier(client);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/quotation_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/quotation_repository.dart';
import '../../auth/providers/auth_provider.dart';

final quotationRepositoryProvider = Provider<QuotationRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return QuotationRepository(client);
});

class QuotationListState {
  final List<Quotation> quotations;
  final bool isLoading;
  final String? error;
  final String statusFilter; // 'All' | one of QuotationStatus.all

  const QuotationListState({
    this.quotations = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter = 'All',
  });

  QuotationListState copyWith({List<Quotation>? quotations, bool? isLoading, String? error, String? statusFilter}) =>
      QuotationListState(
        quotations: quotations ?? this.quotations,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        statusFilter: statusFilter ?? this.statusFilter,
      );
}

class QuotationListNotifier extends StateNotifier<QuotationListState> {
  final QuotationRepository _repo;
  QuotationListNotifier(this._repo) : super(const QuotationListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _repo.getQuotations(status: state.statusFilter);
      state = state.copyWith(quotations: rows, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setFilter(String status) async {
    state = state.copyWith(statusFilter: status);
    await load();
  }
}

final quotationListProvider =
    StateNotifierProvider<QuotationListNotifier, QuotationListState>((ref) => QuotationListNotifier(ref.watch(quotationRepositoryProvider)));

final quotationDetailProvider = FutureProvider.family<Quotation, int>((ref, id) async {
  return ref.watch(quotationRepositoryProvider).getQuotation(id);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/gst_bill_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/gst_bill_repository.dart';
import '../../auth/providers/auth_provider.dart';

final gstBillRepositoryProvider = Provider<GstBillRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return GstBillRepository(client);
});

class GstBillsState {
  final List<GstBill> bills;
  final GstBillSummary? summary;
  final bool isLoading;
  final String? error;

  const GstBillsState({
    this.bills = const [],
    this.summary,
    this.isLoading = false,
    this.error,
  });

  GstBillsState copyWith({
    List<GstBill>? bills,
    GstBillSummary? summary,
    bool? isLoading,
    String? error,
  }) {
    return GstBillsState(
      bills: bills ?? this.bills,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class GstBillsNotifier extends StateNotifier<GstBillsState> {
  final GstBillRepository _repo;
  GstBillsNotifier(this._repo) : super(const GstBillsState());

  /// Load the full matched set + the summary totals for the current window.
  /// The screen applies status via [status] (server-side) and searches/sorts
  /// the returned set client-side.
  Future<void> load({
    String? status,
    String? period,
    String? dateFrom,
    String? dateTo,
    String? financialYearId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final listRes = await _repo.list(
        status: status,
        period: period,
        dateFrom: dateFrom,
        dateTo: dateTo,
        financialYearId: financialYearId,
      );
      // Summary is not status-scoped (the server buckets all statuses itself).
      final sum = await _repo.summary(
        period: period,
        dateFrom: dateFrom,
        dateTo: dateTo,
        financialYearId: financialYearId,
      );
      state = GstBillsState(bills: listRes.bills, summary: sum);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> voidBill(int id) => _repo.voidBill(id);
  Future<void> unvoidBill(int id) => _repo.unvoidBill(id);
  Future<String?> assignGstNumber(int id) => _repo.assignGstNumber(id);
}

final gstBillsProvider = StateNotifierProvider<GstBillsNotifier, GstBillsState>((ref) {
  return GstBillsNotifier(ref.watch(gstBillRepositoryProvider));
});

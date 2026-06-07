import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class PaymentListState {
  final List<Payment> payments;
  final bool isLoading;
  final String? error;
  final String approvalFilter; // All | Pending | Approved | Rejected (client-side)
  final String search;
  final String period; // '' (all) | thisMonth | lastMonth | thisYear | lastYear | last30days | last90days
  final String? actioningId;

  const PaymentListState({
    this.payments = const [],
    this.isLoading = false,
    this.error,
    this.approvalFilter = 'All',
    this.search = '',
    this.period = '',
    this.actioningId,
  });

  PaymentListState copyWith({
    List<Payment>? payments,
    bool? isLoading,
    String? error,
    String? approvalFilter,
    String? search,
    String? period,
    String? actioningId,
    bool clearActioning = false,
  }) {
    return PaymentListState(
      payments: payments ?? this.payments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      approvalFilter: approvalFilter ?? this.approvalFilter,
      search: search ?? this.search,
      period: period ?? this.period,
      actioningId: clearActioning ? null : (actioningId ?? this.actioningId),
    );
  }
}

class PaymentListNotifier extends StateNotifier<PaymentListState> {
  final PaymentRepository _repo;
  PaymentListNotifier(this._repo) : super(const PaymentListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final payments = await _repo.getPayments(period: state.period.isEmpty ? null : state.period);
      state = state.copyWith(payments: payments, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setApprovalFilter(String f) => state = state.copyWith(approvalFilter: f);
  void setSearch(String s) => state = state.copyWith(search: s);
  Future<void> setPeriod(String p) async {
    state = state.copyWith(period: p);
    await load();
  }

  Future<String?> approve(String id) async {
    state = state.copyWith(actioningId: id);
    try {
      await _repo.approvePayment(id);
      state = state.copyWith(
        clearActioning: true,
        payments: [for (final p in state.payments) p.id == id ? p.copyWith(approvalStatus: 'Approved') : p],
      );
      return null;
    } catch (e) {
      state = state.copyWith(clearActioning: true);
      return e.toString();
    }
  }

  Future<String?> reject(String id, String? remarks) async {
    state = state.copyWith(actioningId: id);
    try {
      await _repo.rejectPayment(id, remarks: remarks);
      state = state.copyWith(
        clearActioning: true,
        payments: [for (final p in state.payments) p.id == id ? p.copyWith(approvalStatus: 'Rejected') : p],
      );
      return null;
    } catch (e) {
      state = state.copyWith(clearActioning: true);
      return e.toString();
    }
  }
}

final paymentListProvider = StateNotifierProvider<PaymentListNotifier, PaymentListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return PaymentListNotifier(PaymentRepository(client));
});

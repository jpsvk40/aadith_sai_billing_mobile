import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class PaymentListState {
  final List<Payment> payments;
  final bool isLoading;
  final String? error;

  const PaymentListState({this.payments = const [], this.isLoading = false, this.error});

  PaymentListState copyWith({List<Payment>? payments, bool? isLoading, String? error}) {
    return PaymentListState(payments: payments ?? this.payments, isLoading: isLoading ?? this.isLoading, error: error);
  }
}

class PaymentListNotifier extends StateNotifier<PaymentListState> {
  final PaymentRepository _repo;
  PaymentListNotifier(this._repo) : super(const PaymentListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final payments = await _repo.getPayments();
      state = PaymentListState(payments: payments);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final paymentListProvider = StateNotifierProvider<PaymentListNotifier, PaymentListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return PaymentListNotifier(PaymentRepository(client));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../auth/providers/auth_provider.dart';

class InvoiceListState {
  final List<Invoice> invoices;
  final bool isLoading;
  final String? error;

  const InvoiceListState({this.invoices = const [], this.isLoading = false, this.error});

  InvoiceListState copyWith({List<Invoice>? invoices, bool? isLoading, String? error}) {
    return InvoiceListState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InvoiceListNotifier extends StateNotifier<InvoiceListState> {
  final InvoiceRepository _repo;
  InvoiceListNotifier(this._repo) : super(const InvoiceListState());

  Future<void> load({String? status, String? search}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final invoices = await _repo.getInvoices(paymentStatus: status, search: search);
      state = InvoiceListState(invoices: invoices);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final invoiceListProvider = StateNotifierProvider<InvoiceListNotifier, InvoiceListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return InvoiceListNotifier(InvoiceRepository(client));
});

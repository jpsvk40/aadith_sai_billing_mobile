import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/credit_note_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/credit_note_repository.dart';
import '../../auth/providers/auth_provider.dart';

final creditNoteRepositoryProvider = Provider<CreditNoteRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return CreditNoteRepository(client);
});

// ── Customer credit notes list (status-filtered, mirrors the quotations list) ──

class CustomerCreditNoteListState {
  final List<CustomerCreditNote> notes;
  final bool isLoading;
  final String? error;
  final String statusFilter; // 'All' | one of CustomerCreditNoteStatus.all

  const CustomerCreditNoteListState({
    this.notes = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter = 'All',
  });

  CustomerCreditNoteListState copyWith({
    List<CustomerCreditNote>? notes,
    bool? isLoading,
    String? error,
    String? statusFilter,
  }) =>
      CustomerCreditNoteListState(
        notes: notes ?? this.notes,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        statusFilter: statusFilter ?? this.statusFilter,
      );
}

class CustomerCreditNoteListNotifier extends StateNotifier<CustomerCreditNoteListState> {
  final CreditNoteRepository _repo;
  CustomerCreditNoteListNotifier(this._repo) : super(const CustomerCreditNoteListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _repo.listCustomerCreditNotes(status: state.statusFilter);
      state = state.copyWith(notes: rows, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setFilter(String status) async {
    state = state.copyWith(statusFilter: status);
    await load();
  }
}

final customerCreditNoteListProvider =
    StateNotifierProvider<CustomerCreditNoteListNotifier, CustomerCreditNoteListState>(
        (ref) => CustomerCreditNoteListNotifier(ref.watch(creditNoteRepositoryProvider)));

// ── Vendor credit notes list (simple) ──

final vendorCreditNoteListProvider = FutureProvider<List<VendorCreditNote>>((ref) async {
  return ref.watch(creditNoteRepositoryProvider).listVendorCreditNotes();
});

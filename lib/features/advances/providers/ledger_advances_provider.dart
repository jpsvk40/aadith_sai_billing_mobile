import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/ledger_advance_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/ledger_advance_repository.dart';
import '../../auth/providers/auth_provider.dart';

class LedgerAdvancesState {
  final String party; // 'VENDOR' | 'CUSTOMER'
  final List<LedgerAdvance> advances;
  final bool isLoading;
  final String? error;

  const LedgerAdvancesState({
    this.party = 'VENDOR',
    this.advances = const [],
    this.isLoading = false,
    this.error,
  });

  LedgerAdvancesState copyWith({
    String? party,
    List<LedgerAdvance>? advances,
    bool? isLoading,
    String? error,
  }) {
    return LedgerAdvancesState(
      party: party ?? this.party,
      advances: advances ?? this.advances,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Sum of unadjusted balance across OPEN advances — the web header figure.
  double get openBalance =>
      advances.where((a) => a.isOpen).fold<double>(0, (s, a) => s + a.balance);
}

class LedgerAdvancesNotifier extends StateNotifier<LedgerAdvancesState> {
  final LedgerAdvanceRepository _repo;
  LedgerAdvancesNotifier(this._repo) : super(const LedgerAdvancesState());

  Future<void> load({String? party}) async {
    final p = party ?? state.party;
    state = state.copyWith(party: p, isLoading: true, error: null);
    try {
      final rows = await _repo.list(party: p);
      state = LedgerAdvancesState(party: p, advances: rows);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create an advance for the currently selected party, then reload.
  /// Throws on failure so the screen can surface the message.
  Future<void> create({
    required String partyName,
    required double amount,
    String paymentMode = 'Bank Transfer',
    String? notes,
  }) async {
    await _repo.create(
      party: state.party,
      partyName: partyName,
      amount: amount,
      paymentMode: paymentMode,
      notes: notes,
    );
    await load();
  }

  Future<void> adjust({required int id, required double amount, String? reference}) async {
    await _repo.adjust(id: id, amount: amount, reference: reference);
    await load();
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await load();
  }
}

final ledgerAdvancesProvider =
    StateNotifierProvider<LedgerAdvancesNotifier, LedgerAdvancesState>((ref) {
  final client = ApiClient.getInstance(
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
  );
  return LedgerAdvancesNotifier(LedgerAdvanceRepository(client));
});

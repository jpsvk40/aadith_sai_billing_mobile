import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/legal_case_model.dart';
import 'letters_provider.dart'; // reuses correspondenceRepositoryProvider

/// List state for the Legal Cases tab. All cases are loaded once (server caps at
/// 500) and status/type/search filtering happens client-side in the screen, so
/// the filter chips can show live counts.
class LegalCasesState {
  final List<LegalCase> cases;
  final bool isLoading;
  final String? error;

  const LegalCasesState({
    this.cases = const [],
    this.isLoading = false,
    this.error,
  });

  LegalCasesState copyWith({List<LegalCase>? cases, bool? isLoading, String? error}) => LegalCasesState(
        cases: cases ?? this.cases,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  int get openCount => cases.where((c) => !c.isClosed).length;
  int get upcomingHearings => cases.where((c) => c.hearingUpcoming).length;
}

class LegalCasesNotifier extends StateNotifier<LegalCasesState> {
  final Ref _ref;
  LegalCasesNotifier(this._ref) : super(const LegalCasesState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _ref.read(correspondenceRepositoryProvider).getCases();
      state = state.copyWith(cases: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final legalCasesProvider = StateNotifierProvider<LegalCasesNotifier, LegalCasesState>((ref) {
  return LegalCasesNotifier(ref);
});

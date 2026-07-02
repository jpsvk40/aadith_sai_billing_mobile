import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/letter_model.dart';
import '../../../data/repositories/correspondence_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

final correspondenceRepositoryProvider = Provider<CorrespondenceRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return CorrespondenceRepository(client);
});

class LettersState {
  final List<Letter> letters;
  final bool isLoading;
  final String? error;
  final String scope; // 'awaiting' | 'all'
  final String query;

  const LettersState({
    this.letters = const [],
    this.isLoading = false,
    this.error,
    this.scope = 'awaiting',
    this.query = '',
  });

  LettersState copyWith({List<Letter>? letters, bool? isLoading, String? error, String? scope, String? query}) =>
      LettersState(
        letters: letters ?? this.letters,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        scope: scope ?? this.scope,
        query: query ?? this.query,
      );
}

class LettersNotifier extends StateNotifier<LettersState> {
  final CorrespondenceRepository _repo;
  LettersNotifier(this._repo) : super(const LettersState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = state.scope == 'awaiting'
          ? await _repo.getDue()
          : await _repo.getLetters(q: state.query);
      state = state.copyWith(letters: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setScope(String scope) async {
    if (scope == state.scope) return;
    state = state.copyWith(scope: scope);
    await load();
  }

  Future<void> setQuery(String q) async {
    state = state.copyWith(query: q);
    if (state.scope == 'all') await load();
  }
}

final lettersProvider = StateNotifierProvider<LettersNotifier, LettersState>((ref) {
  return LettersNotifier(ref.watch(correspondenceRepositoryProvider));
});

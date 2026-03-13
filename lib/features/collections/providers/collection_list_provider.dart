import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class CollectionListState {
  final List<Collection> collections;
  final bool isLoading;
  final String? error;

  const CollectionListState({this.collections = const [], this.isLoading = false, this.error});

  CollectionListState copyWith({List<Collection>? collections, bool? isLoading, String? error}) {
    return CollectionListState(collections: collections ?? this.collections, isLoading: isLoading ?? this.isLoading, error: error);
  }
}

class CollectionListNotifier extends StateNotifier<CollectionListState> {
  final CollectionRepository _repo;
  CollectionListNotifier(this._repo) : super(const CollectionListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final collections = await _repo.getCollections();
      state = CollectionListState(collections: collections);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final collectionListProvider = StateNotifierProvider<CollectionListNotifier, CollectionListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return CollectionListNotifier(CollectionRepository(client));
});

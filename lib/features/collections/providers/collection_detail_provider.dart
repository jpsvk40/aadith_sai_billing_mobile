import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

final collectionDetailProvider = FutureProvider.family<Collection, String>((ref, id) async {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return CollectionRepository(client).getCollectionDetail(id);
});

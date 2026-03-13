import '../network/api_client.dart';
import '../models/collection_model.dart';
import '../../core/constants/api_constants.dart';

class CollectionRepository {
  final ApiClient _client;
  CollectionRepository(this._client);

  Future<List<Collection>> getCollections({int page = 1, int limit = 20}) async {
    final data = await _client.get(ApiConstants.collections, queryParams: {
      'page': page,
      'limit': limit,
    });
    final list = data['collections'] ?? data['data'] ?? data;
    if (list is List) {
      return list.map((e) => Collection.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Collection> getCollectionDetail(String id) async {
    final data = await _client.get(ApiConstants.collectionDetail(id));
    return Collection.fromJson(data['collection'] ?? data);
  }

  Future<void> recordCollectionPayment(String id, Map<String, dynamic> paymentData) async {
    await _client.post(ApiConstants.collectionPayment(id), data: paymentData);
  }
}

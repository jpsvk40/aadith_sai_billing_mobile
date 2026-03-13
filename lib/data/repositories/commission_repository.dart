import '../network/api_client.dart';
import '../models/commission_model.dart';
import '../../core/constants/api_constants.dart';

class CommissionRepository {
  final ApiClient _client;
  CommissionRepository(this._client);

  Future<List<Commission>> getCommissions({int page = 1, int limit = 20}) async {
    final data = await _client.get(ApiConstants.commissions, queryParams: {
      'page': page,
      'limit': limit,
    });
    final list = data['commissions'] ?? data['data'] ?? data;
    if (list is List) {
      return list.map((e) => Commission.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<CommissionSummary> getSummary() async {
    final data = await _client.get(ApiConstants.commissionSummary);
    return CommissionSummary.fromJson(data as Map<String, dynamic>);
  }
}

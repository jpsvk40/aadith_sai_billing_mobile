import '../network/api_client.dart';
import '../models/approval_model.dart';
import '../../core/constants/api_constants.dart';

class ApprovalRepository {
  final ApiClient _client;
  ApprovalRepository(this._client);

  /// List approval requests. scope: 'inbox' (actionable by me) | 'mine' | null (all open + recent).
  Future<List<ApprovalRequest>> getRequests({String? scope, String? status}) async {
    final data = await _client.get(ApiConstants.approvalRequests, queryParams: {
      if (scope != null) 'scope': scope,
      if (status != null) 'status': status,
    });
    final list = data is List ? data : (data is Map ? (data['data'] ?? data['requests'] ?? const []) : const []);
    if (list is List) {
      return list.map((e) => ApprovalRequest.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  Future<ApprovalSummary> getSummary() async {
    final data = await _client.get(ApiConstants.approvalSummary);
    return ApprovalSummary.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  Future<void> approve(int id, {String? comment}) =>
      _client.post(ApiConstants.approvalApprove('$id'), data: comment == null ? {} : {'comment': comment});

  Future<void> reject(int id, {String? comment}) =>
      _client.post(ApiConstants.approvalReject('$id'), data: comment == null ? {} : {'comment': comment});

  Future<void> hold(int id, {String? comment}) =>
      _client.post(ApiConstants.approvalHold('$id'), data: comment == null ? {} : {'comment': comment});
}

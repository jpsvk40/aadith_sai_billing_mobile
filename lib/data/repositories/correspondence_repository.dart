import '../network/api_client.dart';
import '../models/letter_model.dart';
import '../../core/constants/api_constants.dart';

class CorrespondenceRepository {
  final ApiClient _client;
  CorrespondenceRepository(this._client);

  List<Letter> _list(dynamic data) =>
      data is List ? data.map((e) => Letter.fromJson((e as Map).cast<String, dynamic>())).toList() : const [];

  /// Letters awaiting reply / action (open + past-or-near due). `days` widens the window.
  Future<List<Letter>> getDue({int days = 0}) async {
    final data = await _client.get(ApiConstants.lettersDue, queryParams: {'days': days});
    return _list(data);
  }

  /// All letters, most recent first. Optional filters + free-text search.
  Future<List<Letter>> getLetters({String? direction, String? status, String? category, String? q}) async {
    final data = await _client.get(ApiConstants.letters, queryParams: {
      if (direction != null) 'direction': direction,
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return _list(data);
  }

  Future<Letter> getLetter(int id) async {
    final data = await _client.get(ApiConstants.letter('$id'));
    return Letter.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Letter> setStatus(int id, String status) async {
    final data = await _client.post(ApiConstants.letterStatus('$id'), data: {'status': status});
    return Letter.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Letter> approve(int id) async {
    final data = await _client.post(ApiConstants.letterApprove('$id'), data: {});
    return Letter.fromJson((data as Map).cast<String, dynamic>());
  }
}

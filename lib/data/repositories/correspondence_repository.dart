import '../network/api_client.dart';
import '../models/letter_model.dart';
import '../models/legal_case_model.dart';
import '../../core/constants/api_constants.dart';

class CorrespondenceRepository {
  final ApiClient _client;
  CorrespondenceRepository(this._client);

  // Legal-case endpoints reuse the module's `/api/correspondence` base path.
  // Kept local (not in ApiConstants) so this repo owns the whole correspondence surface.
  static const String _casesBase = '/api/correspondence/cases';
  static const String _proceedingsBase = '/api/correspondence/proceedings';

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

  // ─── Legal Cases (gated: correspondence_legal) ───

  List<LegalCase> _caseList(dynamic data) =>
      data is List ? data.map((e) => LegalCase.fromJson((e as Map).cast<String, dynamic>())).toList() : const [];

  /// All active cases, newest first. Optional server-side status / type filter.
  Future<List<LegalCase>> getCases({String? status, String? caseType}) async {
    final data = await _client.get(_casesBase, queryParams: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (caseType != null && caseType.isNotEmpty) 'caseType': caseType,
    });
    return _caseList(data);
  }

  /// A single case with its proceedings timeline included.
  Future<LegalCase> getCase(int id) async {
    final data = await _client.get('$_casesBase/$id');
    return LegalCase.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Create a case. Backend requires only `title`; all other fields optional.
  Future<LegalCase> createCase(Map<String, dynamic> body) async {
    final data = await _client.post(_casesBase, data: body);
    return LegalCase.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Patch case fields (e.g. status progression). Returns the bare case (no proceedings).
  Future<LegalCase> updateCase(int id, Map<String, dynamic> body) async {
    final data = await _client.patch('$_casesBase/$id', data: body);
    return LegalCase.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Add a proceeding; the backend syncs the case's nextHearingDate from `nextDate`.
  Future<void> addProceeding(int caseId, Map<String, dynamic> body) async {
    await _client.post('$_casesBase/$caseId/proceedings', data: body);
  }

  Future<void> deleteProceeding(int proceedingId) async {
    await _client.delete('$_proceedingsBase/$proceedingId');
  }
}

import '../network/api_client.dart';
import '../models/erp_list_models.dart';
import '../../core/constants/api_constants.dart';

/// Lists + create/edit for the ERP module tabs (Projects / Machinery / Tenders).
/// Codes (projectCode/machineCode/tenderCode) are server-generated — never sent.
class ErpRepository {
  final ApiClient _client;
  ErpRepository(this._client);

  List<T> _rows<T>(dynamic data, String key, T Function(Map<String, dynamic>) fromJson) {
    final list = data is List
        ? data
        : (data is Map ? (data[key] as List? ?? const []) : const []);
    return list.map((e) => fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// Unwrap a single record — the API sometimes wraps it (`{machine: {...}}`) and
  /// sometimes returns the object flat. Falls back to the outer map.
  Map<String, dynamic> _obj(dynamic data, String key) {
    if (data is Map) {
      final inner = data[key];
      if (inner is Map) return inner.cast<String, dynamic>();
      return data.cast<String, dynamic>();
    }
    return const {};
  }

  Future<List<Project>> getProjects() async {
    final data = await _client.get(ApiConstants.projects);
    return _rows(data, 'projects', Project.fromJson);
  }

  Future<List<Machine>> getMachines() async {
    final data = await _client.get(ApiConstants.machinery);
    return _rows(data, 'machines', Machine.fromJson);
  }

  Future<List<Tender>> getTenders() async {
    final data = await _client.get(ApiConstants.tenders);
    return _rows(data, 'tenders', Tender.fromJson);
  }

  // ─── Machinery (module `machinery`) ───────────────────────────────────────
  Future<Map<String, dynamic>> getMachine(int id) async {
    final data = await _client.get('${ApiConstants.machinery}/$id');
    return _obj(data, 'machine');
  }

  Future<Map<String, dynamic>> createMachine(Map<String, dynamic> body) async {
    final data = await _client.post(ApiConstants.machinery, data: body);
    return _obj(data, 'machine');
  }

  Future<Map<String, dynamic>> updateMachine(int id, Map<String, dynamic> body) async {
    final data = await _client.patch('${ApiConstants.machinery}/$id', data: body);
    return _obj(data, 'machine');
  }

  // ─── Projects (module `projects`) ─────────────────────────────────────────
  Future<Map<String, dynamic>> getProject(int id) async {
    final data = await _client.get('${ApiConstants.projects}/$id');
    return _obj(data, 'project');
  }

  Future<Map<String, dynamic>> createProject(Map<String, dynamic> body) async {
    final data = await _client.post(ApiConstants.projects, data: body);
    return _obj(data, 'project');
  }

  Future<Map<String, dynamic>> updateProject(int id, Map<String, dynamic> body) async {
    final data = await _client.patch('${ApiConstants.projects}/$id', data: body);
    return _obj(data, 'project');
  }

  // ─── Tenders (module `tender`) ────────────────────────────────────────────
  Future<Map<String, dynamic>> getTender(int id) async {
    final data = await _client.get('${ApiConstants.tenders}/$id');
    return _obj(data, 'tender');
  }

  Future<Map<String, dynamic>> createTender(Map<String, dynamic> body) async {
    final data = await _client.post(ApiConstants.tenders, data: body);
    return _obj(data, 'tender');
  }

  /// PATCH edits fields only — it does NOT accept `status`. Change status via
  /// [setTenderStatus] (the dedicated `POST /api/tenders/:id/status` endpoint).
  Future<Map<String, dynamic>> updateTender(int id, Map<String, dynamic> body) async {
    final data = await _client.patch('${ApiConstants.tenders}/$id', data: body);
    return _obj(data, 'tender');
  }

  Future<void> setTenderStatus(int id, String status) async {
    await _client.post('${ApiConstants.tenders}/$id/status', data: {'status': status});
  }
}

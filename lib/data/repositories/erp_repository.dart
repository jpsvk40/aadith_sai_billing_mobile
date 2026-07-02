import '../network/api_client.dart';
import '../models/erp_list_models.dart';
import '../../core/constants/api_constants.dart';

/// Read-only lists for the ERP module tabs. The web owns create/edit; mobile views.
class ErpRepository {
  final ApiClient _client;
  ErpRepository(this._client);

  List<T> _rows<T>(dynamic data, String key, T Function(Map<String, dynamic>) fromJson) {
    final list = data is List
        ? data
        : (data is Map ? (data[key] as List? ?? const []) : const []);
    return list.map((e) => fromJson((e as Map).cast<String, dynamic>())).toList();
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
}

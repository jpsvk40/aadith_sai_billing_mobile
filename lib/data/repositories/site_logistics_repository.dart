import '../network/api_client.dart';
import '../models/site_logistics_model.dart';
import '../../core/constants/api_constants.dart';

class SiteLogisticsRepository {
  final ApiClient _client;
  SiteLogisticsRepository(this._client);

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) from) {
    final raw = data is Map ? (data['data'] ?? data['rows'] ?? data) : data;
    if (raw is List) return raw.map((e) => from(Map<String, dynamic>.from(e as Map))).toList();
    return <T>[];
  }

  Future<List<ProjectLite>> getProjects() async {
    final data = await _client.get(ApiConstants.projects);
    final raw = data is Map ? (data['projects'] ?? data) : data;
    if (raw is List) return raw.map((e) => ProjectLite.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    return <ProjectLite>[];
  }

  // ── Surveys ──
  Future<List<SiteSurvey>> getSurveys({int? projectId}) async {
    final data = await _client.get(ApiConstants.siteSurveys, queryParams: {if (projectId != null) 'projectId': projectId});
    return _list(data, SiteSurvey.fromJson);
  }

  Future<SiteSurvey> createSurvey(Map<String, dynamic> body) async {
    final data = await _client.post(ApiConstants.siteSurveys, data: body);
    return SiteSurvey.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> submitSurvey(String id) => _client.post(ApiConstants.siteSurveySubmit(id));
  Future<void> approveSurvey(String id) => _client.post(ApiConstants.siteSurveyApprove(id));

  // ── Deliveries ──
  Future<List<SiteDelivery>> getDeliveries({int? projectId}) async {
    final data = await _client.get(ApiConstants.siteDeliveries, queryParams: {if (projectId != null) 'projectId': projectId});
    return _list(data, SiteDelivery.fromJson);
  }

  Future<SiteDelivery> createDelivery(Map<String, dynamic> body) async {
    final data = await _client.post(ApiConstants.siteDeliveries, data: body);
    return SiteDelivery.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<SiteDelivery> confirmDelivery(String id, Map<String, dynamic> body) async {
    final data = await _client.post(ApiConstants.siteDeliveryConfirm(id), data: body);
    return SiteDelivery.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Photo upload → { key, url } ──
  Future<SitePhoto> uploadPhoto(String filePath) async {
    final data = await _client.uploadFile(ApiConstants.siteUpload, filePath, fieldName: 'file', fields: {'group': 'mobile'});
    final m = Map<String, dynamic>.from(data as Map);
    return SitePhoto(key: m['key']?.toString(), url: m['url']?.toString());
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/site_logistics_model.dart';
import '../../../data/repositories/site_logistics_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class SiteLogisticsState {
  final List<ProjectLite> projects;
  final List<SiteSurvey> surveys;
  final List<SiteDelivery> deliveries;
  final int? projectId;
  final bool isLoading;
  final String? error;

  const SiteLogisticsState({
    this.projects = const [],
    this.surveys = const [],
    this.deliveries = const [],
    this.projectId,
    this.isLoading = false,
    this.error,
  });

  SiteLogisticsState copyWith({
    List<ProjectLite>? projects,
    List<SiteSurvey>? surveys,
    List<SiteDelivery>? deliveries,
    int? projectId,
    bool? isLoading,
    String? error,
    bool clearProject = false,
  }) {
    return SiteLogisticsState(
      projects: projects ?? this.projects,
      surveys: surveys ?? this.surveys,
      deliveries: deliveries ?? this.deliveries,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SiteLogisticsNotifier extends StateNotifier<SiteLogisticsState> {
  final SiteLogisticsRepository _repo;
  SiteLogisticsNotifier(this._repo) : super(const SiteLogisticsState());

  SiteLogisticsRepository get repo => _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final projects = state.projects.isEmpty ? await _repo.getProjects() : state.projects;
      final surveys = await _repo.getSurveys(projectId: state.projectId);
      final deliveries = await _repo.getDeliveries(projectId: state.projectId);
      state = state.copyWith(projects: projects, surveys: surveys, deliveries: deliveries, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setProject(int? id) async {
    state = state.copyWith(projectId: id, clearProject: id == null);
    await load();
  }

  Future<void> submitSurvey(String id) async { await _repo.submitSurvey(id); await load(); }
  Future<void> approveSurvey(String id) async { await _repo.approveSurvey(id); await load(); }
  Future<void> confirmDelivery(String id, Map<String, dynamic> body) async { await _repo.confirmDelivery(id, body); await load(); }
}

final siteLogisticsProvider = StateNotifierProvider<SiteLogisticsNotifier, SiteLogisticsState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return SiteLogisticsNotifier(SiteLogisticsRepository(client));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/repositories/alert_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class AlertState {
  final List<Alert> alerts;
  final bool isLoading;
  final String? error;
  final String statusTab; // active | acknowledged | resolved
  final int activeCount;
  final int acknowledgedCount;
  final int resolvedCount;
  final Map<String, int> bySeverity;
  final String? actioningId;

  const AlertState({
    this.alerts = const [],
    this.isLoading = false,
    this.error,
    this.statusTab = 'active',
    this.activeCount = 0,
    this.acknowledgedCount = 0,
    this.resolvedCount = 0,
    this.bySeverity = const {},
    this.actioningId,
  });

  AlertState copyWith({
    List<Alert>? alerts,
    bool? isLoading,
    String? error,
    String? statusTab,
    int? activeCount,
    int? acknowledgedCount,
    int? resolvedCount,
    Map<String, int>? bySeverity,
    String? actioningId,
    bool clearActioning = false,
  }) {
    return AlertState(
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusTab: statusTab ?? this.statusTab,
      activeCount: activeCount ?? this.activeCount,
      acknowledgedCount: acknowledgedCount ?? this.acknowledgedCount,
      resolvedCount: resolvedCount ?? this.resolvedCount,
      bySeverity: bySeverity ?? this.bySeverity,
      actioningId: clearActioning ? null : (actioningId ?? this.actioningId),
    );
  }
}

class AlertNotifier extends StateNotifier<AlertState> {
  final AlertRepository _repo;
  AlertNotifier(this._repo) : super(const AlertState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final alerts = await _repo.getAlerts(status: state.statusTab);
      state = state.copyWith(alerts: alerts, isLoading: false, clearActioning: true);
      _loadSummary();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadSummary() async {
    try {
      final s = await _repo.getSummary();
      final sev = (s['bySeverity'] as Map?) ?? const {};
      state = state.copyWith(
        activeCount: (s['active'] as num?)?.toInt() ?? 0,
        acknowledgedCount: (s['acknowledged'] as num?)?.toInt() ?? 0,
        resolvedCount: (s['resolved'] as num?)?.toInt() ?? 0,
        bySeverity: sev.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );
    } catch (_) {}
  }

  Future<void> setStatus(String s) async {
    state = state.copyWith(statusTab: s);
    await load();
  }

  Future<String?> approve(Alert a) async {
    if (a.relatedId == null) return 'No payment linked to this alert.';
    state = state.copyWith(actioningId: a.id);
    try {
      await _repo.approvePayment(a.relatedId!);
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(clearActioning: true);
      return e.toString();
    }
  }

  Future<String?> reject(Alert a, String? remarks) async {
    if (a.relatedId == null) return 'No payment linked to this alert.';
    state = state.copyWith(actioningId: a.id);
    try {
      await _repo.rejectPayment(a.relatedId!, remarks);
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(clearActioning: true);
      return e.toString();
    }
  }

  Future<void> acknowledge(String id) async {
    state = state.copyWith(actioningId: id);
    try {
      await _repo.acknowledge(id);
      await load();
    } catch (_) {
      state = state.copyWith(clearActioning: true);
    }
  }

  Future<void> resolve(String id) async {
    state = state.copyWith(actioningId: id);
    try {
      await _repo.resolve(id);
      await load();
    } catch (_) {
      state = state.copyWith(clearActioning: true);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repo.markAsRead(id);
    } catch (_) {}
  }
}

final alertProvider = StateNotifierProvider<AlertNotifier, AlertState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return AlertNotifier(AlertRepository(client));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/customer_trace_model.dart';
import '../../../data/models/advisor_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/insights_repository.dart';
import '../../auth/providers/auth_provider.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return InsightsRepository(client);
});

// ─── Customer Trace ───────────────────────────────────────────────────────────

/// Family key — (customerId, comparisonMode). Records are value-equal, so the
/// provider re-fetches only when the customer or the period changes.
typedef TraceArgs = ({String id, String mode});

final customerTraceProvider = FutureProvider.family<CustomerTrace, TraceArgs>((ref, args) async {
  return ref.watch(insightsRepositoryProvider).customerTrace(args.id, args.mode);
});

// ─── Sales Advisor (two-step: GET cached → optional POST /run) ─────────────────

class SalesAdvisorState {
  final SalesAdvisor? result;
  final bool checking; // initial GET in flight
  final bool running; // POST /run in flight
  final String? error;
  final String mode;

  const SalesAdvisorState({
    this.result,
    this.checking = false,
    this.running = false,
    this.error,
    this.mode = 'last_30_days',
  });

  bool get hasResult => result != null && result!.hasAnalysis;

  SalesAdvisorState copyWith({
    SalesAdvisor? result,
    bool clearResult = false,
    bool? checking,
    bool? running,
    String? error,
    bool clearError = false,
    String? mode,
  }) =>
      SalesAdvisorState(
        result: clearResult ? null : (result ?? this.result),
        checking: checking ?? this.checking,
        running: running ?? this.running,
        error: clearError ? null : (error ?? this.error),
        mode: mode ?? this.mode,
      );
}

class SalesAdvisorNotifier extends StateNotifier<SalesAdvisorState> {
  final InsightsRepository _repo;
  SalesAdvisorNotifier(this._repo) : super(const SalesAdvisorState());

  /// GET the cached analysis. Missing cache => result stays null (empty state).
  Future<void> load() async {
    state = state.copyWith(checking: true, clearError: true);
    try {
      final data = await _repo.salesAdvisorGet(state.mode);
      state = state.copyWith(
        checking: false,
        result: data.hasAnalysis ? data : null,
        clearResult: !data.hasAnalysis,
      );
    } catch (_) {
      // Non-fatal: keep any prior result, just stop the spinner.
      state = state.copyWith(checking: false);
    }
  }

  Future<void> setMode(String mode) async {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode, clearResult: true, clearError: true);
    await load();
  }

  /// POST /run — compute + cache (long). Renders whatever comes back even if aiError set.
  Future<void> run() async {
    state = state.copyWith(running: true, clearError: true);
    try {
      final data = await _repo.salesAdvisorRun(state.mode);
      state = state.copyWith(running: false, result: data);
    } catch (e) {
      state = state.copyWith(running: false, error: e.toString());
    }
  }
}

final salesAdvisorProvider =
    StateNotifierProvider<SalesAdvisorNotifier, SalesAdvisorState>((ref) => SalesAdvisorNotifier(ref.watch(insightsRepositoryProvider)));

// ─── Inventory Advisor (two-step) ──────────────────────────────────────────────

class InventoryAdvisorState {
  final InventoryAdvisor? result;
  final bool checking;
  final bool running;
  final String? error;

  const InventoryAdvisorState({this.result, this.checking = false, this.running = false, this.error});

  bool get hasResult => result != null && result!.hasAnalysis;

  InventoryAdvisorState copyWith({
    InventoryAdvisor? result,
    bool clearResult = false,
    bool? checking,
    bool? running,
    String? error,
    bool clearError = false,
  }) =>
      InventoryAdvisorState(
        result: clearResult ? null : (result ?? this.result),
        checking: checking ?? this.checking,
        running: running ?? this.running,
        error: clearError ? null : (error ?? this.error),
      );
}

class InventoryAdvisorNotifier extends StateNotifier<InventoryAdvisorState> {
  final InsightsRepository _repo;
  InventoryAdvisorNotifier(this._repo) : super(const InventoryAdvisorState());

  Future<void> load() async {
    state = state.copyWith(checking: true, clearError: true);
    try {
      final data = await _repo.inventoryAdvisorGet();
      state = state.copyWith(
        checking: false,
        result: data.hasAnalysis ? data : null,
        clearResult: !data.hasAnalysis,
      );
    } catch (_) {
      state = state.copyWith(checking: false);
    }
  }

  Future<void> run() async {
    state = state.copyWith(running: true, clearError: true);
    try {
      final data = await _repo.inventoryAdvisorRun();
      state = state.copyWith(running: false, result: data);
    } catch (e) {
      state = state.copyWith(running: false, error: e.toString());
    }
  }
}

final inventoryAdvisorProvider = StateNotifierProvider<InventoryAdvisorNotifier, InventoryAdvisorState>(
    (ref) => InventoryAdvisorNotifier(ref.watch(insightsRepositoryProvider)));

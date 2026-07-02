import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/command_center_model.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class CommandCenterState {
  final MoneyBand? money;
  final ActionCenter? action;
  final ActionCenter? mineAction;
  final ProjectsSummary? projects;
  final MachinerySummary? machinery;
  final TendersSummary? tenders;
  final MyWork? myWork;
  final bool isLoading;
  final String? error;

  const CommandCenterState({
    this.money,
    this.action,
    this.mineAction,
    this.projects,
    this.machinery,
    this.tenders,
    this.myWork,
    this.isLoading = false,
    this.error,
  });

  CommandCenterState copyWith({
    MoneyBand? money,
    ActionCenter? action,
    ActionCenter? mineAction,
    ProjectsSummary? projects,
    MachinerySummary? machinery,
    TendersSummary? tenders,
    MyWork? myWork,
    bool? isLoading,
    String? error,
  }) =>
      CommandCenterState(
        money: money ?? this.money,
        action: action ?? this.action,
        mineAction: mineAction ?? this.mineAction,
        projects: projects ?? this.projects,
        machinery: machinery ?? this.machinery,
        tenders: tenders ?? this.tenders,
        myWork: myWork ?? this.myWork,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class CommandCenterNotifier extends StateNotifier<CommandCenterState> {
  final DashboardRepository _repo;
  CommandCenterNotifier(this._repo) : super(const CommandCenterState());

  /// Loads every panel needed by the lenses. Each call is guarded so a module the
  /// company doesn't run (or a non-exec role that 403s) degrades to null, not a crash.
  Future<void> load({Set<String> modules = const {}}) async {
    state = state.copyWith(isLoading: true, error: null);
    bool has(String m) => modules.isEmpty || modules.contains(m);

    Future<T?> tryGet<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    // Fire everything in parallel; skip endpoints for modules that aren't enabled.
    final results = await Future.wait([
      tryGet(_repo.getMoneyBand),
      tryGet(() => _repo.getActionCenter()),
      tryGet(() => _repo.getActionCenter(mine: true)),
      tryGet(_repo.getMyWork),
      has('projects') ? tryGet(_repo.getProjectsSummary) : Future.value(null),
      has('machinery') ? tryGet(_repo.getMachinerySummary) : Future.value(null),
      has('tender') ? tryGet(_repo.getTendersSummary) : Future.value(null),
    ]);

    final money = results[0] as MoneyBand?;
    state = CommandCenterState(
      money: money,
      action: results[1] as ActionCenter?,
      mineAction: results[2] as ActionCenter?,
      myWork: results[3] as MyWork?,
      projects: results[4] as ProjectsSummary?,
      machinery: results[5] as MachinerySummary?,
      tenders: results[6] as TendersSummary?,
      isLoading: false,
      error: money == null ? 'Could not load your command center' : null,
    );
  }
}

final commandCenterProvider = StateNotifierProvider<CommandCenterNotifier, CommandCenterState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return CommandCenterNotifier(DashboardRepository(client));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/approval_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/repositories/approval_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class ApprovalsState {
  final List<ApprovalItem> items;
  final int awaitingMe;
  final int pending;
  final int hold;
  final int mine;
  final String scope; // 'inbox' | 'all' | 'mine'
  final String? statusFilter; // null = All | PENDING | HOLD | APPROVED | REJECTED
  final bool isLoading;
  final String? error;
  final String? actioningId;

  const ApprovalsState({
    this.items = const [],
    this.awaitingMe = 0,
    this.pending = 0,
    this.hold = 0,
    this.mine = 0,
    this.scope = 'inbox',
    this.statusFilter,
    this.isLoading = false,
    this.error,
    this.actioningId,
  });

  ApprovalsState copyWith({
    List<ApprovalItem>? items,
    int? awaitingMe,
    int? pending,
    int? hold,
    int? mine,
    String? scope,
    String? statusFilter,
    bool clearStatusFilter = false,
    bool? isLoading,
    String? error,
    String? actioningId,
    bool clearActioning = false,
  }) =>
      ApprovalsState(
        items: items ?? this.items,
        awaitingMe: awaitingMe ?? this.awaitingMe,
        pending: pending ?? this.pending,
        hold: hold ?? this.hold,
        mine: mine ?? this.mine,
        scope: scope ?? this.scope,
        statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
        isLoading: isLoading ?? this.isLoading,
        error: error,
        actioningId: clearActioning ? null : (actioningId ?? this.actioningId),
      );
}

class ApprovalsNotifier extends StateNotifier<ApprovalsState> {
  final ApprovalRepository _repo;
  final PaymentRepository _payRepo;
  ApprovalsNotifier(this._repo, this._payRepo) : super(const ApprovalsState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final engineScope = state.scope == 'all' ? null : state.scope;
      final results = await Future.wait([
        _repo.getRequests(scope: engineScope, status: state.statusFilter),
        _repo.getSummary(),
        _payRepo.getPayments(approvalStatus: 'Pending'),
      ]);
      final requests = results[0] as List<ApprovalRequest>;
      final summary = results[1] as ApprovalSummary;
      final pendingPayments = (results[2] as List<Payment>).where((p) => p.approvalStatus == 'Pending').toList();

      // Payments are the admin's action queue for every scope except "my requests".
      // The pending-payment queue is Pending-only, so hide it when filtering to a non-pending status.
      final statusAllowsPayments = state.statusFilter == null || state.statusFilter == 'PENDING';
      final includePayments = state.scope != 'mine' && statusAllowsPayments;
      final items = <ApprovalItem>[
        if (includePayments) ...pendingPayments.map(ApprovalItem.fromPayment),
        ...requests.map(ApprovalItem.fromRequest),
      ];

      state = state.copyWith(
        items: items,
        awaitingMe: pendingPayments.length + summary.inboxForMe,
        pending: pendingPayments.length + summary.pending,
        hold: summary.hold,
        mine: summary.mine,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setScope(String scope) {
    if (scope == state.scope) return;
    state = state.copyWith(scope: scope);
    load();
  }

  /// Filter by request status. Pass null (or 'All') to clear and show open items.
  void setStatus(String? status) {
    final next = (status == null || status.isEmpty || status == 'All') ? null : status;
    if (next == state.statusFilter) return;
    state = next == null ? state.copyWith(clearStatusFilter: true) : state.copyWith(statusFilter: next);
    load();
  }

  /// Returns null on success, else an error message.
  Future<String?> approve(ApprovalItem item, {String? comment}) => _act(item, () async {
        if (item.isPayment) {
          await _payRepo.approvePayment(item.id);
        } else {
          await _repo.approve(int.parse(item.id), comment: comment);
        }
      });

  Future<String?> reject(ApprovalItem item, {String? comment}) => _act(item, () async {
        if (item.isPayment) {
          await _payRepo.rejectPayment(item.id, remarks: comment);
        } else {
          await _repo.reject(int.parse(item.id), comment: comment);
        }
      });

  Future<String?> _act(ApprovalItem item, Future<void> Function() action) async {
    state = state.copyWith(actioningId: item.id);
    try {
      await action();
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(clearActioning: true);
      return e.toString();
    }
  }
}

final approvalsProvider = StateNotifierProvider<ApprovalsNotifier, ApprovalsState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return ApprovalsNotifier(ApprovalRepository(client), PaymentRepository(client));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/procurement_models.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/procurement_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Sentinel so [ProcurementHubState.copyWith] can distinguish "keep the current
/// error" from "clear the error" (passing null).
const Object _keep = Object();

final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return ProcurementRepository(client);
});

/// All four hub lists in one place so the tab counts + Payment Request actions
/// stay consistent. Requisition/RFQ errors surface; PO/Payment failures degrade
/// to empty lists (mirrors the web hub which tolerates those two).
class ProcurementHubState {
  final List<Requisition>? requisitions;
  final List<Rfq>? rfqs;
  final List<PurchaseOrder>? purchaseOrders;
  final List<PaymentRequest>? paymentRequests;
  final bool isLoading;
  final String? error;

  const ProcurementHubState({
    this.requisitions,
    this.rfqs,
    this.purchaseOrders,
    this.paymentRequests,
    this.isLoading = false,
    this.error,
  });

  ProcurementHubState copyWith({
    List<Requisition>? requisitions,
    List<Rfq>? rfqs,
    List<PurchaseOrder>? purchaseOrders,
    List<PaymentRequest>? paymentRequests,
    bool? isLoading,
    Object? error = _keep,
  }) {
    return ProcurementHubState(
      requisitions: requisitions ?? this.requisitions,
      rfqs: rfqs ?? this.rfqs,
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      paymentRequests: paymentRequests ?? this.paymentRequests,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _keep) ? this.error : error as String?,
    );
  }

  bool get hasAny =>
      requisitions != null || rfqs != null || purchaseOrders != null || paymentRequests != null;
}

class ProcurementHubNotifier extends StateNotifier<ProcurementHubState> {
  final ProcurementRepository _repo;
  ProcurementHubNotifier(this._repo) : super(const ProcurementHubState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    Object? err;
    // Kick all four off concurrently; each tolerates its own failure.
    final reqF = _repo.getRequisitions().catchError((e) {
      err ??= e;
      return <Requisition>[];
    });
    final rfqF = _repo.getRfqs().catchError((e) {
      err ??= e;
      return <Rfq>[];
    });
    final poF = _repo.getPurchaseOrders().catchError((_) => <PurchaseOrder>[]);
    final prF = _repo.getPaymentRequests().catchError((_) => <PaymentRequest>[]);

    final requisitions = await reqF;
    final rfqs = await rfqF;
    final purchaseOrders = await poF;
    final paymentRequests = await prF;

    state = ProcurementHubState(
      requisitions: requisitions,
      rfqs: rfqs,
      purchaseOrders: purchaseOrders,
      paymentRequests: paymentRequests,
      isLoading: false,
      error: (requisitions.isEmpty && rfqs.isEmpty && err != null) ? err.toString() : null,
    );
  }

  /// Approve / hold / reject a payment request with an optimistic status flip.
  /// Reverts + rethrows on failure so the UI can surface the server message.
  Future<void> paymentAction(int id, String action, {String? reason}) async {
    final list = state.paymentRequests;
    if (list == null) return;
    final idx = list.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final prev = list[idx];
    final optimistic = action == 'approve'
        ? 'PAID'
        : action == 'hold'
            ? 'HOLD'
            : 'REJECTED';
    final updated = [...list]..[idx] = prev.copyWith(status: optimistic);
    state = state.copyWith(paymentRequests: updated);
    try {
      switch (action) {
        case 'approve':
          await _repo.approvePaymentRequest(id);
          break;
        case 'hold':
          await _repo.holdPaymentRequest(id, reason: reason);
          break;
        case 'reject':
          await _repo.rejectPaymentRequest(id);
          break;
      }
      // Reconcile against the server (spawns VendorPayment on approve, etc.).
      await load();
    } catch (e) {
      final cur = state.paymentRequests;
      if (cur != null) {
        final j = cur.indexWhere((p) => p.id == id);
        if (j >= 0) {
          final reverted = [...cur]..[j] = prev;
          state = state.copyWith(paymentRequests: reverted);
        }
      }
      rethrow;
    }
  }
}

final procurementHubProvider =
    StateNotifierProvider<ProcurementHubNotifier, ProcurementHubState>((ref) {
  return ProcurementHubNotifier(ref.watch(procurementRepositoryProvider));
});

// ─── Detail providers (read-only lines/status views) ───

final requisitionDetailProvider =
    FutureProvider.autoDispose.family<Requisition, int>((ref, id) {
  return ref.watch(procurementRepositoryProvider).getRequisitionDetail(id);
});

final rfqDetailProvider = FutureProvider.autoDispose.family<Rfq, int>((ref, id) {
  return ref.watch(procurementRepositoryProvider).getRfqDetail(id);
});

final purchaseOrderDetailProvider =
    FutureProvider.autoDispose.family<PurchaseOrder, int>((ref, id) {
  return ref.watch(procurementRepositoryProvider).getPurchaseOrderDetail(id);
});

/// Vendor id → name map (best-effort; empty on failure) for RFQ detail labels.
final procurementVendorNamesProvider =
    FutureProvider.autoDispose<Map<int, String>>((ref) async {
  try {
    return await ref.watch(procurementRepositoryProvider).getVendorNames();
  } catch (_) {
    return <int, String>{};
  }
});

/// Projects for the requisition form dropdown (best-effort; empty on failure /
/// when the user lacks the `projects` module).
final procurementProjectsProvider =
    FutureProvider.autoDispose<List<ProcProject>>((ref) async {
  try {
    return await ref.watch(procurementRepositoryProvider).getProjects();
  } catch (_) {
    return <ProcProject>[];
  }
});

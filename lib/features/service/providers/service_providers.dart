import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/models/service_ticket_model.dart';
import '../../../data/models/service_item_model.dart';
import '../../../data/models/service_contract_model.dart';
import '../../../data/models/customer_service_history_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Shared ServiceRepository (uses the singleton ApiClient + auth logout-on-401).
final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return ServiceRepository(client);
});

// ─── My Tickets (technician queue / admin all-tickets) ───
class MyTicketsState {
  final List<ServiceTicket> tickets;
  final bool isLoading;
  final String? error;
  final String statusFilter; // 'All' or a status
  final String search;
  const MyTicketsState({this.tickets = const [], this.isLoading = false, this.error, this.statusFilter = 'All', this.search = ''});
  MyTicketsState copyWith({List<ServiceTicket>? tickets, bool? isLoading, String? error, String? statusFilter, String? search}) => MyTicketsState(
        tickets: tickets ?? this.tickets,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        statusFilter: statusFilter ?? this.statusFilter,
        search: search ?? this.search,
      );
}

class MyTicketsNotifier extends StateNotifier<MyTicketsState> {
  final ServiceRepository _repo;
  final bool mineOnly; // technician → assignedTo=me; admin → all
  MyTicketsNotifier(this._repo, {required this.mineOnly}) : super(const MyTicketsState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final tickets = await _repo.getTickets(
        assignedTo: mineOnly ? 'me' : null,
        status: state.statusFilter,
        search: state.search.isEmpty ? null : state.search,
      );
      state = state.copyWith(tickets: tickets, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setStatus(String s) async {
    state = state.copyWith(statusFilter: s);
    await load();
  }

  void setSearch(String s) => state = state.copyWith(search: s);
}

/// Technician's own queue.
final myTicketsProvider = StateNotifierProvider<MyTicketsNotifier, MyTicketsState>((ref) {
  return MyTicketsNotifier(ref.watch(serviceRepositoryProvider), mineOnly: true);
});

/// Admin's all-tickets queue (same notifier, no assignedTo filter).
final allTicketsProvider = StateNotifierProvider<MyTicketsNotifier, MyTicketsState>((ref) {
  return MyTicketsNotifier(ref.watch(serviceRepositoryProvider), mineOnly: false);
});

// ─── Ticket detail + attachments (invalidate to refresh after an action) ───
final ticketDetailProvider = FutureProvider.family<ServiceTicket, int>((ref, id) async {
  return ref.watch(serviceRepositoryProvider).getTicket(id);
});

final ticketAttachmentsProvider = FutureProvider.family<List<ServiceAttachment>, int>((ref, id) async {
  return ref.watch(serviceRepositoryProvider).getAttachments(id);
});

// ─── Warranty RMA "out at company" worklist (F2) ───
final rmaOutstandingProvider = FutureProvider.autoDispose<List<ServiceTicketRma>>((ref) async {
  return ref.watch(serviceRepositoryProvider).rmaOutstanding();
});

// ─── Customer service/maintenance history (F1) ───
final customerServiceHistoryProvider = FutureProvider.family.autoDispose<CustomerServiceHistory, int>((ref, customerId) async {
  return ref.watch(serviceRepositoryProvider).customerHistory(customerId);
});

// ─── AMC due visits (Today tab) — 60-day window to match the web "PM visits due" panel ───
final dueVisitsProvider = FutureProvider<List<ContractVisit>>((ref) async {
  return ref.watch(serviceRepositoryProvider).getDueVisits(days: 60);
});

// ─── Service dashboard (admin) ───
final serviceDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(serviceRepositoryProvider).dashboard();
});

// ─── Warranty register / items (admin) ───
final serviceItemsProvider = FutureProvider.family<List<ServiceItem>, String>((ref, search) async {
  return ref.watch(serviceRepositoryProvider).getItems(search: search.isEmpty ? null : search);
});

// ─── AMC contracts (admin) ───
final serviceContractsProvider = FutureProvider<List<ServiceContract>>((ref) async {
  return ref.watch(serviceRepositoryProvider).getContracts();
});

// ─── Reports bundle (admin): revenue + technician productivity + parts usage ───
final serviceReportsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(serviceRepositoryProvider);
  final results = await Future.wait([repo.serviceRevenue(), repo.technicianProductivity(), repo.partsUsage()]);
  return {
    'revenue': results[0],
    'technicians': results[1],
    'parts': results[2],
  };
});

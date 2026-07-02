import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_ticket_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/service_providers.dart';
import '../service_status.dart';

/// Technician's assigned ticket queue (assignedTo=me). Doubles as the admin all-tickets list
/// when [adminMode] is true.
class MyTicketsScreen extends ConsumerStatefulWidget {
  final bool adminMode;
  const MyTicketsScreen({super.key, this.adminMode = false});
  @override
  ConsumerState<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends ConsumerState<MyTicketsScreen> {
  static const _filters = ['All', 'OPEN', 'ASSIGNED', 'IN_PROGRESS', 'AWAITING_PARTS', 'READY', 'DELIVERED'];

  StateNotifierProvider<MyTicketsNotifier, MyTicketsState> get _provider =>
      widget.adminMode ? allTicketsProvider : myTicketsProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(_provider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final isAdmin = widget.adminMode;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isAdmin ? 'Service Tickets' : 'My Tickets'),
        actions: [
          IconButton(
            tooltip: 'Warranty lookup',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.go('/service/warranty-lookup'),
          ),
          if (isAdmin)
            IconButton(icon: const Icon(Icons.add), onPressed: () => context.go('/service/tickets/create')),
        ],
      ),
      body: Column(
        children: [
          _statusFilter(state),
          Expanded(
            child: state.isLoading && state.tickets.isEmpty
                ? const LoadingIndicator()
                : state.error != null && state.tickets.isEmpty
                    ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(_provider.notifier).load())
                    : RefreshIndicator(
                        onRefresh: () => ref.read(_provider.notifier).load(),
                        child: state.tickets.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 120),
                                EmptyStateWidget(message: 'No tickets here', icon: Icons.build_circle_outlined),
                              ])
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 4, bottom: 24),
                                itemCount: state.tickets.length,
                                itemBuilder: (ctx, i) => _ticketCard(state.tickets[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statusFilter(MyTicketsState state) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final f = _filters[i];
          final selected = state.statusFilter == f;
          return ChoiceChip(
            label: Text(f == 'All' ? 'All' : ServiceStatus.label(f)),
            selected: selected,
            onSelected: (_) => ref.read(_provider.notifier).setStatus(f),
            selectedColor: AppColors.primaryLight,
            labelStyle: TextStyle(color: selected ? AppColors.primaryDark : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5),
          );
        },
      ),
    );
  }

  Widget _ticketCard(ServiceTicket t) {
    return AppCard(
      onTap: () => context.go('/service/tickets/${t.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.ticketNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              ServiceStatusChip(status: t.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (t.serviceItem?.label.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${t.serviceItem!.label}  ·  ${t.serviceItem!.serialNumber ?? ''}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 4),
          Text(t.reportedProblem, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _tag(ServiceStatus.serviceTypeLabel(t.serviceType), AppColors.textSecondary),
              const SizedBox(width: 8),
              _tag(t.priority, ServiceStatus.priorityColor(t.priority)),
              const Spacer(),
              if (t.slaBreached)
                const Row(children: [Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger), SizedBox(width: 3), Text('SLA', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700))]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

/// Thin wrapper so the router can mount the technician variant.
class TechnicianTicketsScreen extends ConsumerWidget {
  const TechnicianTicketsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defensive: a non-service user should never reach here (guards handle it), but keep it graceful.
    final user = ref.watch(authProvider).user;
    return MyTicketsScreen(adminMode: user?.isTechnician != true);
  }
}

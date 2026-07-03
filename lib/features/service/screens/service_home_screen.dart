import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_ticket_model.dart';
import '../../../data/models/service_contract_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/service_providers.dart';
import '../service_status.dart';

const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Technician landing / "My Day" — a field-focused home: what's assigned to me,
/// what visits are due, what needs attention. No financials (that's the owner's
/// Service dashboard). Reuses myTicketsProvider (assignedTo=me) + dueVisitsProvider.
class ServiceHomeScreen extends ConsumerStatefulWidget {
  const ServiceHomeScreen({super.key});
  @override
  ConsumerState<ServiceHomeScreen> createState() => _ServiceHomeScreenState();
}

class _ServiceHomeScreenState extends ConsumerState<ServiceHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(myTicketsProvider.notifier).load());
  }

  bool _visitOverdue(ContractVisit v) => v.overdue;
  bool _visitToday(ContractVisit v) {
    final d = v.scheduledDate;
    if (d == null || v.overdue) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final ticketsState = ref.watch(myTicketsProvider);
    final visitsAsync = ref.watch(dueVisitsProvider);

    final myOpen = ticketsState.tickets.where((t) => t.isOpen).toList();
    final slaBreached = myOpen.where((t) => t.slaBreached).toList();
    final ready = myOpen.where((t) => t.status == 'READY').toList();
    final visits = visitsAsync.valueOrNull?.where((v) => !v.isDone).toList() ?? [];
    final visitsToday = visits.where(_visitToday).length;
    final visitsOverdue = visits.where(_visitOverdue).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(myTicketsProvider.notifier).load();
            ref.invalidate(dueVisitsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _hero(user?.name ?? 'Technician', myOpen.length, visitsToday, visitsOverdue),
              const SizedBox(height: 16),
              _quickActions(),
              const SizedBox(height: 18),
              if (slaBreached.isNotEmpty || visitsOverdue > 0) ...[
                _attention(slaBreached.length, visitsOverdue, ready.length),
                const SizedBox(height: 18),
              ],
              _sectionHeader('My open tickets', myOpen.length, () => context.go('/service/tickets')),
              const SizedBox(height: 8),
              if (ticketsState.isLoading && myOpen.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
              else if (myOpen.isEmpty)
                _emptyMini('No open tickets assigned to you', Icons.check_circle_outline)
              else
                ...myOpen.take(5).map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _TicketTile(ticket: t))),
              const SizedBox(height: 18),
              _sectionHeader("Today's visits", visitsToday + visitsOverdue, () => context.go('/service/today')),
              const SizedBox(height: 8),
              if (visits.isEmpty)
                _emptyMini('No AMC visits due', Icons.event_available)
              else
                ...visits.where((v) => _visitToday(v) || _visitOverdue(v)).take(3).map(
                      (v) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _VisitMiniTile(visit: v)),
                    ),
              if (visits.isNotEmpty && !visits.any((v) => _visitToday(v) || _visitOverdue(v)))
                _emptyMini('Nothing due today — ${visits.length} upcoming', Icons.event_available),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Hero ───
  Widget _hero(String name, int open, int today, int overdue) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final now = DateTime.now();
    final dateStr = '${_weekdays[now.weekday]}, ${now.day} ${_months[now.month]}';
    final first = name.split(' ').first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 18, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(children: [
          Positioned(right: -30, top: -34, child: _bubble(120)),
          Positioned(right: 40, bottom: -40, child: _bubble(84)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$greeting 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(first, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(dateStr, style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 12.5)),
            const SizedBox(height: 18),
            Row(children: [
              _stat('$open', 'My tickets'),
              _divider(),
              _stat('$today', 'Due today'),
              _divider(),
              _stat('$overdue', 'Overdue', danger: overdue > 0),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _bubble(double s) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)));
  Widget _divider() => Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.22), margin: const EdgeInsets.symmetric(horizontal: 14));
  Widget _stat(String value, String label, {bool danger = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: danger ? const Color(0xFFFECACA) : Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]);

  // ─── Quick actions ───
  Widget _quickActions() => Row(children: [
        _action('Warranty', Icons.qr_code_scanner, AppColors.primary, () => context.go('/service/warranty-lookup')),
        const SizedBox(width: 12),
        _action('Calendar', Icons.calendar_month, const Color(0xFF7C3AED), () => context.go('/service/calendar')),
        const SizedBox(width: 12),
        _action('All tickets', Icons.list_alt, const Color(0xFF0D9488), () => context.go('/service/tickets')),
      ]);

  Widget _action(String label, IconData icon, Color color, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ]),
          ),
        ),
      );

  // ─── Needs-attention banner ───
  Widget _attention(int sla, int overdueVisits, int ready) {
    final parts = <String>[
      if (sla > 0) '$sla SLA-breached ticket${sla == 1 ? '' : 's'}',
      if (overdueVisits > 0) '$overdueVisits overdue visit${overdueVisits == 1 ? '' : 's'}',
      if (ready > 0) '$ready ready for pickup',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.30)),
      ),
      child: Row(children: [
        const Icon(Icons.priority_high_rounded, color: AppColors.danger, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Needs attention', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(parts.join(' · '), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  // ─── helpers ───
  Widget _sectionHeader(String title, int count, VoidCallback onView) => Row(children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
          ),
        const Spacer(),
        TextButton(onPressed: onView, child: const Text('View all')),
      ]);

  Widget _emptyMini(String msg, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        ]),
      );
}

class _TicketTile extends StatelessWidget {
  final ServiceTicket ticket;
  const _TicketTile({required this.ticket});
  @override
  Widget build(BuildContext context) {
    final accent = ServiceStatus.color(ticket.status);
    return InkWell(
      onTap: () => context.go('/service/tickets/${ticket.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(ticket.ticketNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary))),
                    if (ticket.slaBreached)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(5)),
                        child: const Text('SLA', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ServiceStatusChip(status: ticket.status),
                  ]),
                  const SizedBox(height: 3),
                  Text(ticket.customerName, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (ticket.reportedProblem.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(ticket.reportedProblem, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ]),
              ),
            ),
            const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.chevron_right, color: AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}

class _VisitMiniTile extends StatelessWidget {
  final ContractVisit visit;
  const _VisitMiniTile({required this.visit});
  @override
  Widget build(BuildContext context) {
    final overdue = visit.overdue;
    final accent = overdue ? AppColors.danger : AppColors.primary;
    final d = visit.scheduledDate;
    return InkWell(
      onTap: () => context.go('/service/today'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(d != null ? '${d.day}' : '—', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accent, height: 1)),
              Text(d != null ? _months[d.month] : '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(visit.customer?.name ?? 'AMC visit', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${visit.contractNumber ?? 'AMC'} · Visit #${visit.sequence}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          if (overdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(6)),
              child: const Text('OVERDUE', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
    );
  }
}

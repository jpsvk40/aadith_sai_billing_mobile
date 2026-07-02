import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/calendar_event_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../providers/service_providers.dart';

/// Service calendar — AMC preventive-maintenance visits, AMC renewals and other dated events
/// (invoice due, etc.) on a month grid. Tap a day to see its events; tap an event to open it.
class ServiceCalendarScreen extends ConsumerStatefulWidget {
  const ServiceCalendarScreen({super.key});
  @override
  ConsumerState<ServiceCalendarScreen> createState() => _ServiceCalendarScreenState();
}

class _ServiceCalendarScreenState extends ConsumerState<ServiceCalendarScreen> {
  final DateTime _first = DateTime.now().subtract(const Duration(days: 90));
  final DateTime _last = DateTime.now().add(const Duration(days: 365));
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  bool _loading = true;
  String? _error;
  final Map<DateTime, List<CalendarEvent>> _byDay = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Scope to the service module (AMC PM visits + renewals) — keeps CRM/other noise out.
      final events = await ref.read(serviceRepositoryProvider).getCalendar(from: _first, to: _last, module: 'warranty_service');
      _byDay.clear();
      for (final e in events) {
        _byDay.putIfAbsent(e.day, () => []).add(e);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<CalendarEvent> _eventsFor(DateTime day) => _byDay[DateTime(day.year, day.month, day.day)] ?? const [];

  @override
  Widget build(BuildContext context) {
    final dayEvents = _eventsFor(_selected);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Service Calendar'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.all(12),
                      child: TableCalendar<CalendarEvent>(
                        firstDay: _first,
                        lastDay: _last,
                        focusedDay: _focused,
                        calendarFormat: _format,
                        selectedDayPredicate: (d) => isSameDay(_selected, d),
                        eventLoader: _eventsFor,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        availableCalendarFormats: const {CalendarFormat.month: 'Month', CalendarFormat.twoWeeks: '2 weeks', CalendarFormat.week: 'Week'},
                        onFormatChanged: (f) => setState(() => _format = f),
                        onPageChanged: (f) => _focused = f,
                        onDaySelected: (selected, focused) => setState(() { _selected = selected; _focused = focused; }),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.35), shape: BoxShape.circle),
                          selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          markerDecoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
                          markersMaxCount: 4,
                          outsideDaysVisible: false,
                        ),
                        headerStyle: const HeaderStyle(formatButtonShowsNext: false, titleCentered: true),
                      ),
                    ),
                    Expanded(
                      child: dayEvents.isEmpty
                          ? Center(child: Text('No events on ${AppDateUtils.formatDisplay(_selected)}', style: const TextStyle(color: AppColors.textSecondary)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              itemCount: dayEvents.length,
                              itemBuilder: (ctx, i) => _eventTile(dayEvents[i]),
                            ),
                    ),
                  ],
                ),
    );
  }

  bool _canReschedule(CalendarEvent e) => e.reschedulable && e.refType == 'service_contract_visit' && e.refId != null;

  Widget _eventTile(CalendarEvent e) {
    final canResched = _canReschedule(e);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: e.color.withValues(alpha: 0.15), child: Icon(e.icon, color: e.color, size: 20)),
        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
        subtitle: Text(
          [
            e.category[0] + e.category.substring(1).toLowerCase(),
            if (e.description != null) e.description,
            if (canResched) 'tap to reschedule',
          ].whereType<String>().join(' · '),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Icon(canResched ? Icons.event_repeat : (e.link != null ? Icons.chevron_right : Icons.circle_outlined),
            color: canResched ? AppColors.primary : AppColors.textMuted, size: 20),
        onTap: (canResched || e.link != null) ? () => _onEventTap(e) : null,
      ),
    );
  }

  Future<void> _onEventTap(CalendarEvent e) async {
    final canResched = _canReschedule(e);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (canResched)
            ListTile(leading: const Icon(Icons.event_repeat, color: AppColors.primary), title: const Text('Reschedule visit'), onTap: () => Navigator.pop(ctx, 'reschedule')),
          if (e.link != null)
            ListTile(leading: const Icon(Icons.open_in_new), title: const Text('Open'), onTap: () => Navigator.pop(ctx, 'open')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'open' && e.link != null) {
      context.go(_resolveLink(e));
    } else if (action == 'reschedule') {
      await _reschedule(e);
    }
  }

  Future<void> _reschedule(CalendarEvent e) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: e.start.isBefore(DateTime.now()) ? DateTime.now() : e.start,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Reschedule PM visit',
    );
    if (picked == null || !mounted) return;
    try {
      await ref.read(serviceRepositoryProvider).rescheduleEvent(refType: e.refType!, refId: e.refId, startAt: picked);
      // Keep dependent views (Today / dashboard due-visits) fresh.
      ref.invalidate(dueVisitsProvider);
      await _load();
      if (mounted) {
        setState(() => _selected = DateTime(picked.year, picked.month, picked.day));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Visit moved to ${AppDateUtils.formatDisplay(picked)}'), backgroundColor: AppColors.success));
      }
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString()), backgroundColor: AppColors.danger));
    }
  }

  // Map the backend link hint to a mobile route we actually have.
  String _resolveLink(CalendarEvent e) {
    if (e.refType == 'service_contract_visit' || e.refType == 'service_contract') return '/service/contracts';
    if (e.module == 'invoices') return '/invoices';
    return '/service/contracts';
  }
}

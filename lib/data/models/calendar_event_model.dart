// A calendar event from GET /api/calendar (stored + derived: AMC visits/renewals, invoice due, …).
import 'package:flutter/material.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final String category; // SERVICE | PAYMENT | BILLING | TASK | …
  final String? module; // warranty_service | invoices | crm | …
  final DateTime start;
  final bool allDay;
  final String? refType;
  final dynamic refId;
  final String? link; // in-app route hint (e.g. /service/contracts)
  final String status;
  final bool reschedulable;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    this.category = 'TASK',
    this.module,
    required this.start,
    this.allDay = true,
    this.refType,
    this.refId,
    this.link,
    this.status = 'OPEN',
    this.reschedulable = false,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: j['description']?.toString(),
        category: (j['category'] ?? 'TASK').toString(),
        module: j['module']?.toString(),
        start: DateTime.tryParse((j['start'] ?? '').toString())?.toLocal() ?? DateTime(2000),
        allDay: j['allDay'] != false,
        refType: j['refType']?.toString(),
        refId: j['refId'],
        link: j['link']?.toString(),
        status: (j['status'] ?? 'OPEN').toString(),
        reschedulable: j['reschedulable'] == true,
      );

  /// Date-only key for grouping on the calendar.
  DateTime get day => DateTime(start.year, start.month, start.day);

  Color get color => switch (category) {
        'SERVICE' => const Color(0xFF0D6EFD),
        'PAYMENT' => const Color(0xFF198754),
        'BILLING' => const Color(0xFFF59E0B),
        'TASK' => const Color(0xFF7C3AED),
        _ => const Color(0xFF6C757D),
      };

  IconData get icon => switch (category) {
        'SERVICE' => Icons.handyman_outlined,
        'PAYMENT' => Icons.payments_outlined,
        'BILLING' => Icons.description_outlined,
        'TASK' => Icons.task_alt_outlined,
        _ => Icons.event_note_outlined,
      };
}

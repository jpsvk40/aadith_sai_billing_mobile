import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Service ticket status helpers — labels, colours, and the allowed next-status FSM
/// (mirrors backend helpers/warranty.js STATUS_TRANSITIONS exactly).
class ServiceStatus {
  static const Map<String, List<String>> transitions = {
    'OPEN': ['ASSIGNED', 'DIAGNOSED', 'CANCELLED'],
    'ASSIGNED': ['DIAGNOSED', 'AWAITING_PARTS', 'AWAITING_APPROVAL', 'IN_PROGRESS', 'CANCELLED'],
    'DIAGNOSED': ['AWAITING_PARTS', 'AWAITING_APPROVAL', 'IN_PROGRESS', 'CANCELLED'],
    'AWAITING_PARTS': ['IN_PROGRESS', 'AWAITING_APPROVAL', 'CANCELLED'],
    'AWAITING_APPROVAL': ['IN_PROGRESS', 'AWAITING_PARTS', 'CANCELLED'],
    'IN_PROGRESS': ['READY', 'AWAITING_PARTS', 'AWAITING_APPROVAL', 'CANCELLED'],
    'READY': ['DELIVERED', 'IN_PROGRESS'],
    'DELIVERED': ['CLOSED'],
    'CLOSED': <String>[],
    'CANCELLED': <String>[],
  };

  static List<String> nextStatuses(String from) => transitions[from] ?? const [];

  static String label(String status) => switch (status) {
        'OPEN' => 'Open',
        'ASSIGNED' => 'Assigned',
        'DIAGNOSED' => 'Diagnosed',
        'AWAITING_PARTS' => 'Awaiting Parts',
        'AWAITING_APPROVAL' => 'Awaiting Approval',
        'IN_PROGRESS' => 'In Progress',
        'READY' => 'Ready',
        'DELIVERED' => 'Delivered',
        'CLOSED' => 'Closed',
        'CANCELLED' => 'Cancelled',
        _ => status,
      };

  static Color color(String status) => switch (status) {
        'READY' || 'DELIVERED' || 'CLOSED' => AppColors.success,
        'CANCELLED' => AppColors.danger,
        'AWAITING_PARTS' || 'AWAITING_APPROVAL' => AppColors.warning,
        'IN_PROGRESS' || 'DIAGNOSED' => AppColors.info,
        _ => AppColors.primary,
      };

  static String serviceTypeLabel(String t) => switch (t) {
        'IN_WARRANTY' => 'In Warranty',
        'OUT_OF_WARRANTY' => 'Out of Warranty',
        'AMC' => 'AMC',
        'PAID_REPAIR' => 'Paid Repair',
        'INSTALLATION' => 'Installation',
        _ => t,
      };

  static Color priorityColor(String p) => switch (p) {
        'URGENT' => AppColors.danger,
        'HIGH' => AppColors.warning,
        'LOW' => AppColors.textMuted,
        _ => AppColors.textSecondary,
      };
}

/// Small pill widget for a service status.
class ServiceStatusChip extends StatelessWidget {
  final String status;
  const ServiceStatusChip({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final c = ServiceStatus.color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(ServiceStatus.label(status), style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

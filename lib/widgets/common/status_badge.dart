import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color get _bgColor {
    switch (status.toLowerCase()) {
      case 'paid': case 'completed': case 'delivered': case 'active': return AppColors.successLight;
      case 'pending': case 'draft': case 'processing': return AppColors.warningLight;
      case 'overdue': case 'cancelled': case 'rejected': return AppColors.dangerLight;
      case 'dispatched': case 'invoiced': return AppColors.infoLight;
      default: return AppColors.divider;
    }
  }

  Color get _textColor {
    switch (status.toLowerCase()) {
      case 'paid': case 'completed': case 'delivered': case 'active': return AppColors.success;
      case 'pending': case 'draft': case 'processing': return const Color(0xFF856404);
      case 'overdue': case 'cancelled': case 'rejected': return AppColors.danger;
      case 'dispatched': case 'invoiced': return const Color(0xFF055160);
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

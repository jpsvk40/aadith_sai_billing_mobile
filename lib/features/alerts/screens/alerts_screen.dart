import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/alert_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(alertProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: state.isLoading && state.alerts.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.alerts.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(alertProvider.notifier).load())
              : state.alerts.isEmpty
                  ? const EmptyStateWidget(message: 'No alerts', icon: Icons.notifications_none_outlined)
                  : RefreshIndicator(
                      onRefresh: () => ref.read(alertProvider.notifier).load(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.alerts.length,
                        itemBuilder: (context, i) {
                          final alert = state.alerts[i];
                          return Dismissible(
                            key: Key(alert.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: AppColors.success,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.check, color: AppColors.white),
                            ),
                            onDismissed: (_) => ref.read(alertProvider.notifier).markRead(alert.id),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: alert.isRead ? AppColors.surface : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: alert.isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _iconBg(alert.type),
                                  child: Icon(_icon(alert.type), color: _iconColor(alert.type), size: 20),
                                ),
                                title: Text(alert.message, style: TextStyle(
                                  fontWeight: alert.isRead ? FontWeight.normal : FontWeight.w600,
                                  fontSize: 14,
                                )),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (alert.customerName != null)
                                      Text(alert.customerName!, style: const TextStyle(fontSize: 12)),
                                    if (alert.amount != null)
                                      Text(CurrencyUtils.format(alert.amount), style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                                    Text(AppDateUtils.timeAgo(alert.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                                trailing: alert.isRead ? null : Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                ),
                                onTap: () {
                                  if (!alert.isRead) ref.read(alertProvider.notifier).markRead(alert.id);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  IconData _icon(String type) {
    switch (type.toLowerCase()) {
      case 'payment': return Icons.payment;
      case 'overdue': return Icons.warning_outlined;
      case 'order': return Icons.receipt_long_outlined;
      default: return Icons.info_outline;
    }
  }

  Color _iconBg(String type) {
    switch (type.toLowerCase()) {
      case 'payment': return AppColors.successLight;
      case 'overdue': return AppColors.dangerLight;
      default: return AppColors.infoLight;
    }
  }

  Color _iconColor(String type) {
    switch (type.toLowerCase()) {
      case 'payment': return AppColors.success;
      case 'overdue': return AppColors.danger;
      default: return AppColors.info;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/alert_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/alert_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';

const _sevYellow = Color(0xFFEAB308);
const _sevOrange = Color(0xFFF59E0B);
const _sevPurple = Color(0xFF7C3AED);

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

  Color _sevColor(String s) {
    switch (s) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return _sevOrange;
      case 'medium':
        return _sevYellow;
      case 'low':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _prettyType(String t) =>
      t.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  Future<void> _approve(Alert a) async {
    final err = await ref.read(alertProvider.notifier).approve(a);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Payment approved'),
      backgroundColor: err == null ? AppColors.success : AppColors.danger,
    ));
  }

  Future<void> _reject(Alert a) async {
    final remarks = await _askRemarks();
    if (remarks == null) return;
    final err = await ref.read(alertProvider.notifier).reject(a, remarks.isEmpty ? null : remarks);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Payment rejected'),
      backgroundColor: AppColors.danger,
    ));
  }

  Future<String?> _askRemarks() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payment'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Reason (optional)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Alerts & Notifications')),
      body: state.isLoading && state.alerts.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.alerts.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(alertProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () => ref.read(alertProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: state.alerts.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(state);
                      return _alertCard(state, state.alerts[i - 1]);
                    },
                  ),
                ),
    );
  }

  Widget _header(AlertState s) {
    final sev = s.bySeverity;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 78,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _sevCard('CRITICAL', sev['critical'] ?? 0, AppColors.danger),
                _sevCard('HIGH', sev['high'] ?? 0, _sevOrange),
                _sevCard('MEDIUM', sev['medium'] ?? 0, _sevYellow),
                _sevCard('LOW', sev['low'] ?? 0, AppColors.primary),
                _sevCard('TOTAL ACTIVE', s.activeCount, _sevPurple),
                const SizedBox(width: 14),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                _tab('Active', s.activeCount, 'active', s.statusTab),
                const SizedBox(width: 8),
                _tab('Acknowledged', s.acknowledgedCount, 'acknowledged', s.statusTab),
                const SizedBox(width: 8),
                _tab('Resolved', s.resolvedCount, 'resolved', s.statusTab),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (s.alerts.isEmpty && !s.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 60, right: 14),
              child: EmptyStateWidget(message: 'No alerts here', icon: Icons.notifications_none_outlined),
            ),
        ],
      ),
    );
  }

  Widget _sevCard(String label, int count, Color color) {
    return Container(
      width: 104,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.22)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: Colors.white.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _tab(String label, int count, String value, String current) {
    final sel = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(alertProvider.notifier).setStatus(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppColors.primary : AppColors.border),
          ),
          child: Column(
            children: [
              Text('$count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textPrimary)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: sel ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertCard(AlertState s, Alert a) {
    final c = _sevColor(a.severity);
    final acting = s.actioningId == a.id;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 4, height: 44, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _pill(a.severity.toUpperCase(), c),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_prettyType(a.alertType), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500))),
                          Text(AppDateUtils.timeAgo(a.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      if (a.message.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(a.message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
                      ],
                      if (a.customerName != null || a.amount != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (a.customerName != null) ...[
                              const Icon(Icons.person_outline, size: 13, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Flexible(child: Text(a.customerName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
                            ],
                            if (a.amount != null && a.amount! > 0) ...[
                              const Spacer(),
                              Text(CurrencyUtils.format(a.amount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (a.isPaymentApproval)
            _actionRow(
              left: _btn('Reject', Icons.close, AppColors.danger, false, acting ? null : () => _reject(a)),
              right: _btn('Approve', Icons.check, AppColors.success, true, acting ? null : () => _approve(a), loading: acting),
            )
          else if (a.status == 'active')
            _actionRow(
              left: _btn('Acknowledge', Icons.visibility_outlined, AppColors.primary, false, acting ? null : () => ref.read(alertProvider.notifier).acknowledge(a.id)),
              right: _btn('Resolve', Icons.done_all, AppColors.success, true, acting ? null : () => ref.read(alertProvider.notifier).resolve(a.id), loading: acting),
            ),
        ],
      ),
    );
  }

  Widget _actionRow({required Widget left, required Widget right}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(children: [Expanded(child: left), const SizedBox(width: 10), Expanded(child: right)]),
    );
  }

  Widget _btn(String label, IconData icon, Color color, bool filled, VoidCallback? onTap, {bool loading = false}) {
    final child = loading
        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon, size: 16);
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: child,
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color), padding: const EdgeInsets.symmetric(vertical: 10)),
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
      );
}

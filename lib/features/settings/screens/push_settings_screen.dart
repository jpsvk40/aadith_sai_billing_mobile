import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_pref_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/notification_prefs_provider.dart';

/// Per-alert-type push toggles. Turning one off mutes the OS push for that alert
/// type — the in-app alert is still created and visible under Alerts.
class PushSettingsScreen extends ConsumerStatefulWidget {
  const PushSettingsScreen({super.key});
  @override
  ConsumerState<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends ConsumerState<PushSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(notificationPrefsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationPrefsProvider);
    final n = ref.read(notificationPrefsProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notification Settings')),
      body: async.when(
        loading: () => const LoadingIndicator(message: 'Loading preferences…'),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: n.load),
        data: (items) {
          // Preserve backend order while grouping.
          final groups = <String, List<NotificationPref>>{};
          for (final p in items) {
            groups.putIfAbsent(p.group, () => []).add(p);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
                ),
                child: const Row(children: [
                  Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Choose which alerts push to this device. Turning one off still shows it under Alerts.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
                ]),
              ),
              const SizedBox(height: 16),
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                  child: Text(entry.key.toUpperCase(),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5)),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++)
                        Column(children: [
                          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                          SwitchListTile(
                            value: entry.value[i].enabled,
                            onChanged: (v) => n.toggle(entry.value[i].key, v),
                            title: Text(entry.value[i].label,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            activeThumbColor: AppColors.primary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ]),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ],
          );
        },
      ),
    );
  }
}

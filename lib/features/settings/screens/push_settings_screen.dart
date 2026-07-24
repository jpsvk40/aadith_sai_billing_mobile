import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/push_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_pref_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/notification_prefs_provider.dart';

/// Per-alert-type push toggles. Turning one off mutes the OS push for that alert
/// type — the in-app alert is still created and visible under Alerts.
///
/// Also surfaces a live "delivery diagnostics" card so support (or a TestFlight
/// tester) can see exactly where push registration stops on this device —
/// permission, APNs token, FCM token — without needing Xcode.
class PushSettingsScreen extends ConsumerStatefulWidget {
  const PushSettingsScreen({super.key});
  @override
  ConsumerState<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends ConsumerState<PushSettingsScreen> {
  Map<String, String>? _diag;
  bool _diagLoading = false;

  // The diagnostics card is a support/debug tool, not for regular users. It
  // auto-shows in debug builds; on a release build it stays hidden until the
  // screen title is tapped 7x (so support can walk a user to it). Session-only.
  bool _diagUnlocked = kDebugMode;
  int _diagTapCount = 0;

  static const _diagLabels = {
    'firebase': 'Firebase',
    'platform': 'Platform',
    'permission': 'Permission',
    'apnsToken': 'APNs token',
    'fcmToken': 'FCM token',
    'lastError': 'Last error',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationPrefsProvider.notifier).load();
      if (_diagUnlocked) _loadDiag();
    });
  }

  Future<void> _loadDiag() async {
    setState(() => _diagLoading = true);
    final d = await PushService.instance.collectDiagnostics();
    if (!mounted) return;
    setState(() {
      _diag = d;
      _diagLoading = false;
    });
  }

  /// Reveal the diagnostics card on a release build after 7 title taps.
  void _onTitleTap() {
    if (_diagUnlocked) return;
    _diagTapCount++;
    if (_diagTapCount >= 7) {
      setState(() => _diagUnlocked = true);
      _loadDiag();
      _snack('Push diagnostics unlocked.');
    }
  }

  /// Whether a diagnostic value indicates a problem (renders red).
  bool _isProblem(String key, String value) {
    switch (key) {
      case 'permission':
        return value != 'authorized' && value != 'provisional';
      case 'apnsToken':
      case 'fcmToken':
        return value.startsWith('null');
      case 'firebase':
        return value != 'initialized';
      case 'lastError':
        return value != 'none';
      default:
        return false;
    }
  }

  Future<void> _copyToken() async {
    final token = PushService.instance.fcmToken;
    if (token == null || token.isEmpty) {
      _snack('No FCM token to copy — this device has not registered yet.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: token));
    _snack('FCM token copied to clipboard.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationPrefsProvider);
    final n = ref.read(notificationPrefsProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          behavior: HitTestBehavior.opaque,
          child: const Text('Notification Settings'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_diagUnlocked) await _loadDiag();
          await n.load();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _infoBanner(),
            const SizedBox(height: 16),
            if (_diagUnlocked) ...[
              _diagnosticsCard(),
              const SizedBox(height: 20),
            ],
            ...async.when<List<Widget>>(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: LoadingIndicator(message: 'Loading preferences…'),
                )
              ],
              error: (e, _) => [ErrorStateWidget(message: e.toString(), onRetry: n.load)],
              data: (items) => _prefsGroups(items, n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: const Row(children: [
        Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 20),
        SizedBox(width: 10),
        Expanded(
            child: Text('Choose which alerts push to this device. Turning one off still shows it under Alerts.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
      ]),
    );
  }

  Widget _diagnosticsCard() {
    final diag = _diag;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Text('PUSH DELIVERY DIAGNOSTICS',
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (diag == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Reading device push status…',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                )
              else
                for (final e in diag.entries)
                  _diagRow(_diagLabels[e.key] ?? e.key, e.value, _isProblem(e.key, e.value)),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _diagLoading ? null : _loadDiag,
                    icon: _diagLoading
                        ? const SizedBox(
                            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _copyToken,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy FCM token'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _diagRow(String label, String value, bool problem) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(problem ? Icons.cancel : Icons.check_circle,
              size: 16, color: problem ? Colors.red.shade400 : Colors.green.shade500),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: SelectableText(value,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: problem ? Colors.red.shade400 : AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  List<Widget> _prefsGroups(List<NotificationPref> items, dynamic n) {
    // Preserve backend order while grouping.
    final groups = <String, List<NotificationPref>>{};
    for (final p in items) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }
    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
        child: Text(entry.key.toUpperCase(),
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5)),
      ));
      widgets.add(Container(
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
      ));
      widgets.add(const SizedBox(height: 18));
    }
    return widgets;
  }
}

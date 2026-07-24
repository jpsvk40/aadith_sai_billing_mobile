import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';

/// Wraps the whole app (via MaterialApp.builder). On first frame it checks the
/// backend version gate and, if needed, either HARD-blocks the app with an
/// "Update required" screen or shows a dismissible "Update available" banner.
/// A failed/slow check is a no-op — the app is never blocked by a backend issue.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  static const _prefsKey = 'update_prompt_dismissed_version';
  AppUpdateInfo _info = AppUpdateInfo.none;
  bool _softDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final info = await AppUpdateService().check();
    if (!mounted) return;
    // For a soft prompt, don't nag: suppress if the user already dismissed THIS latest version.
    if (info.severity == UpdateSeverity.soft) {
      final prefs = await SharedPreferences.getInstance();
      final dismissedFor = prefs.getString(_prefsKey);
      if (!mounted) return;
      setState(() {
        _info = info;
        _softDismissed = dismissedFor == info.latestVersion;
      });
      return;
    }
    setState(() => _info = info);
  }

  Future<void> _openStore() async {
    if (_info.storeUrl.isEmpty) return;
    await launchUrl(Uri.parse(_info.storeUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _dismissSoft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _info.latestVersion);
    if (mounted) setState(() => _softDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_info.severity == UpdateSeverity.hard) {
      return _HardGate(info: _info, onUpdate: _openStore);
    }
    return Stack(
      children: [
        widget.child,
        if (_info.severity == UpdateSeverity.soft && !_softDismissed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SoftBanner(info: _info, onUpdate: _openStore, onLater: _dismissSoft),
          ),
      ],
    );
  }
}

const _navy = Color(0xFF0A1A4A);
const _blue = Color(0xFF0060F0);

class _HardGate extends StatelessWidget {
  const _HardGate({required this.info, required this.onUpdate});

  final AppUpdateInfo info;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F6FB),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(color: _navy, shape: BoxShape.circle),
                  child: const Icon(Icons.system_update, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Update required',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _navy),
                ),
                const SizedBox(height: 12),
                Text(
                  info.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                Text(
                  'This version is no longer supported. Please update to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Update now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftBanner extends StatelessWidget {
  const _SoftBanner({required this.info, required this.onUpdate, required this.onLater});

  final AppUpdateInfo info;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: _navy.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6)),
              ],
              border: Border.all(color: const Color(0xFFE6EAF4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: _blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.system_update, color: _blue, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Update available', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
                      SizedBox(height: 2),
                      Text('A newer version is ready in the store.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                TextButton(onPressed: onLater, child: const Text('Later', style: TextStyle(color: Color(0xFF94A3B8)))),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: onUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Update'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

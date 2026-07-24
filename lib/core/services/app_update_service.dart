import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/api_constants.dart';

/// How stale the installed app is versus what the backend advertises.
enum UpdateSeverity {
  /// Up to date (or the check failed / was inconclusive) — do nothing.
  none,

  /// A newer version exists — show a dismissible "Update available" prompt.
  soft,

  /// Installed version is below the minimum supported — block with a hard gate.
  hard,
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.severity,
    required this.currentVersion,
    required this.latestVersion,
    required this.storeUrl,
    required this.message,
  });

  final UpdateSeverity severity;
  final String currentVersion;
  final String latestVersion;
  final String storeUrl;
  final String message;

  static const none = AppUpdateInfo(
    severity: UpdateSeverity.none,
    currentVersion: '',
    latestVersion: '',
    storeUrl: '',
    message: '',
  );
}

/// Fetches the public `/api/app-config` gate and compares it against the
/// installed version. Never throws — a failed/slow check just returns [none]
/// so the app is never blocked by a backend hiccup.
class AppUpdateService {
  AppUpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
            ));

  final Dio _dio;

  Future<AppUpdateInfo> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // e.g. "1.0.2"

      final res = await _dio.get('/api/app-config');
      final data = res.data;
      if (data is! Map) return AppUpdateInfo.none;

      final minSupported = (data['minSupportedVersion'] ?? '0.0.0').toString();
      final latest = (data['latestVersion'] ?? current).toString();
      final urls = (data['updateUrl'] is Map) ? data['updateUrl'] as Map : const {};
      final storeUrl =
          (Platform.isIOS ? urls['ios'] : urls['android'])?.toString() ?? '';
      final message = (data['updateMessage'] ??
              'A new version is available with the latest features and fixes.')
          .toString();

      UpdateSeverity severity;
      if (_isBelow(current, minSupported)) {
        severity = UpdateSeverity.hard;
      } else if (_isBelow(current, latest)) {
        severity = UpdateSeverity.soft;
      } else {
        severity = UpdateSeverity.none;
      }

      // Without a store URL a prompt is useless — degrade to none.
      if (severity != UpdateSeverity.none && storeUrl.isEmpty) {
        return AppUpdateInfo.none;
      }

      return AppUpdateInfo(
        severity: severity,
        currentVersion: current,
        latestVersion: latest,
        storeUrl: storeUrl,
        message: message,
      );
    } catch (_) {
      return AppUpdateInfo.none; // fail-open: never block on a check error
    }
  }

  /// True if semantic version [a] is strictly older than [b] (build metadata
  /// after `+` is ignored). Non-numeric/short parts are treated as 0.
  static bool _isBelow(String a, String b) => _compare(a, b) < 0;

  static int _compare(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }

  static List<int> _parts(String v) {
    final core = v.split('+').first.split('-').first.trim();
    return core
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}

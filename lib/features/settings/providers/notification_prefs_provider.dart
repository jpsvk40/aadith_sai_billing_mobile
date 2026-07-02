import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/notification_pref_model.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationPrefsNotifier extends StateNotifier<AsyncValue<List<NotificationPref>>> {
  final ApiClient _client;
  NotificationPrefsNotifier(this._client) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _client.get(ApiConstants.devicePreferences);
      final items = (data is Map ? (data['items'] as List? ?? const []) : const [])
          .map((e) => NotificationPref.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Optimistically flip a toggle, then persist. Reverts on failure.
  Future<void> toggle(String key, bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data([
      for (final p in current) p.key == key ? p.copyWith(enabled: enabled) : p,
    ]);
    try {
      await _client.put(ApiConstants.devicePreferences, data: {'alertType': key, 'enabled': enabled});
    } catch (_) {
      // Revert on failure.
      state = AsyncValue.data([
        for (final p in state.valueOrNull ?? current) p.key == key ? p.copyWith(enabled: !enabled) : p,
      ]);
    }
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, AsyncValue<List<NotificationPref>>>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return NotificationPrefsNotifier(client);
});

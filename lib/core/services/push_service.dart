import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../data/network/api_client.dart';
import '../constants/api_constants.dart';

/// Background isolate handler. Must be a top-level function. When a message
/// carries a `notification` payload, Android/iOS display it from the tray
/// automatically, so there's nothing to do here for now.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Wraps Firebase Cloud Messaging so alerts arrive as OS push notifications.
///
/// Degrades gracefully: if Firebase isn't configured yet (no google-services.json /
/// GoogleService-Info.plist), [init] catches the failure and every method becomes a
/// no-op, so the app runs normally until the Firebase project is wired up.
///
/// iOS note: an FCM registration token only exists AFTER Apple hands the app an
/// APNs device token. That token arrives asynchronously (a beat after
/// registerForRemoteNotifications) and only if the build's Push Notifications
/// capability / provisioning is valid. So on iOS we (a) wait for the APNs token
/// before asking for the FCM token, (b) retry, and (c) ALWAYS keep an
/// onTokenRefresh listener so a late-arriving token still gets registered.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _available = false;
  bool _inited = false;
  String? _token;

  // Diagnostics — surfaced via [collectDiagnostics] so a debug screen (or a
  // TestFlight tester) can see exactly where iOS push registration stops.
  AuthorizationStatus? _authStatus;
  String? _apnsToken;
  String? _lastError;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'alerts',
    'Alerts',
    description: 'Business alerts, approvals & reminders',
    importance: Importance.high,
  );

  bool get isAvailable => _available;
  String? get fcmToken => _token;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      debugPrint('[PushService] Initializing Firebase...');
      await Firebase.initializeApp();
      _available = true;
      debugPrint('[PushService] Firebase initialized successfully');
    } catch (e) {
      // Firebase not configured (credentials not added yet) — push stays inert.
      _available = false;
      _lastError = 'Firebase init failed: $e';
      debugPrint('[PushService] Firebase initialization failed: $e');
      return;
    }

    // Local notifications: used to surface FCM messages while the app is foregrounded.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    final settings = await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
    _authStatus = settings.authorizationStatus;
    debugPrint('[PushService] Notification permission: ${settings.authorizationStatus}');

    // iOS: show banners while the app is in the foreground too.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    // Attach the refresh listener UNCONDITIONALLY (not only after a successful
    // getToken). On iOS the very first token can arrive late — this guarantees
    // it is registered whenever it shows up, instead of being lost.
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _token = t;
      debugPrint('[PushService] Token refreshed: ${_mask(t)}');
      _send(t);
    });

    FirebaseMessaging.onMessage.listen(_showForeground);
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Called after login / session restore. Registers this device's FCM token with
  /// the backend so alerts fan out to it, and keeps it current on refresh.
  Future<void> registerToken() async {
    if (!_available) {
      debugPrint('[PushService] Firebase not available, skipping token registration');
      return;
    }
    try {
      // iOS: the FCM token depends on the APNs device token from Apple, which
      // arrives asynchronously. Poll for it (up to ~5s) instead of giving up on
      // the first null — that null was the reason no iPhone ever registered.
      if (Platform.isIOS) {
        String? apns = await FirebaseMessaging.instance.getAPNSToken();
        for (var i = 0; apns == null && i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          apns = await FirebaseMessaging.instance.getAPNSToken();
        }
        _apnsToken = apns;
        if (apns == null) {
          _lastError = 'No APNs token — Apple never registered this device '
              '(check Push Notifications capability / provisioning under the Apple team, '
              'and that notifications are allowed in Settings).';
          debugPrint('[PushService] APNs token: NULL — $_lastError');
        } else {
          debugPrint('[PushService] APNs token acquired: ${_mask(apns)}');
        }
      }

      // Retry getToken a few times to ride out transient apns-token-not-set.
      String? token;
      for (var i = 0; i < 3 && token == null; i++) {
        try {
          token = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          _lastError = 'getToken attempt ${i + 1} failed: $e';
          debugPrint('[PushService] $_lastError');
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (token == null) {
        debugPrint('[PushService] No FCM token after retries — nothing registered. '
            'On iOS this almost always means no APNs registration (capability/provisioning).');
        return;
      }
      _token = token;
      _lastError = null;
      debugPrint('[PushService] Obtained FCM token: ${_mask(token)}');
      await _send(token);
      // NOTE: refresh listener is attached in init(), so no need to add it here.
    } catch (e) {
      _lastError = 'registerToken failed: $e';
      debugPrint('[PushService] $_lastError');
    }
  }

  Future<void> _send(String token) async {
    try {
      final client = ApiClient.getInstance(onUnauthorized: () {});
      await client.post(ApiConstants.deviceRegister, data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      debugPrint('[PushService] Device token registered with backend');
    } catch (e) {
      _lastError = 'backend register failed: $e';
      debugPrint('[PushService] Failed to register token with backend: $e');
    }
  }

  /// Called on logout — stop delivering to this device.
  Future<void> unregister() async {
    if (!_available || _token == null) return;
    final token = _token;
    _token = null;
    try {
      final client = ApiClient.getInstance(onUnauthorized: () {});
      await client.post(ApiConstants.deviceUnregister, data: {'token': token});
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {/* best-effort */}
  }

  /// Live snapshot of the push pipeline for a debug screen / support diagnosis.
  /// Re-reads the current values so it reflects the moment it is called.
  Future<Map<String, String>> collectDiagnostics() async {
    String perm = _authStatus?.name ?? 'unknown';
    String apns = _apnsToken == null ? 'null' : 'present (${_mask(_apnsToken!)})';
    String fcm = _token == null ? 'null' : 'present (${_mask(_token!)})';
    if (_available) {
      try {
        final s = await FirebaseMessaging.instance.getNotificationSettings();
        perm = s.authorizationStatus.name;
        if (Platform.isIOS) {
          final a = await FirebaseMessaging.instance.getAPNSToken();
          apns = a == null ? 'null' : 'present (${_mask(a)})';
        }
      } catch (_) {/* keep cached values */}
    }
    return {
      'firebase': _available ? 'initialized' : 'unavailable',
      'platform': Platform.isIOS ? 'ios' : 'android',
      'permission': perm,
      'apnsToken': apns,
      'fcmToken': fcm,
      'lastError': _lastError ?? 'none',
    };
  }

  static String _mask(String t) => t.length <= 10 ? t : '${t.substring(0, 10)}…';
}

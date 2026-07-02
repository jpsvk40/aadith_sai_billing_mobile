import 'dart:io';
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
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _available = false;
  bool _inited = false;
  String? _token;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'alerts',
    'Alerts',
    description: 'Business alerts, approvals & reminders',
    importance: Importance.high,
  );

  bool get isAvailable => _available;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (_) {
      // Firebase not configured (credentials not added yet) — push stays inert.
      _available = false;
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
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    // iOS: show banners while the app is in the foreground too.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

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
    if (!_available) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await _send(token);
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        _send(t);
      });
    } catch (_) {/* offline / permission denied — try again next launch */}
  }

  Future<void> _send(String token) async {
    try {
      final client = ApiClient.getInstance(onUnauthorized: () {});
      await client.post(ApiConstants.deviceRegister, data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {/* best-effort */}
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
}

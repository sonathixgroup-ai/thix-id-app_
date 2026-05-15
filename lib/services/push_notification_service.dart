import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// Push notifications (FCM) + token registration in Supabase.
///
/// What this service does:
/// - Requests permissions on iOS / Android 13+
/// - Obtains the FCM token (mobile + web)
/// - Upserts the token into Supabase (`thix_push_tokens`)
/// - Shows a local notification when the app is foregrounded (mobile)
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  final SupabaseClient _client = SupabaseConfig.client;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  /// For Flutter web, you must provide a VAPID key from Firebase Console.
  /// Add it at build/runtime as: `--dart-define=FIREBASE_VAPID_KEY=...`
  static const String _vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  Future<void> initIfNeeded() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _initLocalNotifications();
      await _configureForegroundHandlers();
    } catch (e, st) {
      debugPrint('PushNotificationService: init failed err=$e');
      debugPrint(st.toString());
    }
  }

  Future<void> onSignedIn({required String userId}) async {
    await initIfNeeded();
    await _requestPermission();
    await _syncToken(userId: userId);

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((t) {
      unawaited(_upsertToken(userId: userId, token: t));
    });
  }

  Future<void> onSignedOut() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(alert: true, announcement: false, badge: true, carPlay: false, criticalAlert: true, provisional: false, sound: true);
    } catch (e) {
      debugPrint('PushNotificationService: requestPermission failed err=$e');
    }
  }

  Future<void> _syncToken({required String userId}) async {
    try {
      final token = await _getToken();
      if (token == null || token.trim().isEmpty) return;
      await _upsertToken(userId: userId, token: token);
    } catch (e, st) {
      debugPrint('PushNotificationService: _syncToken failed err=$e');
      debugPrint(st.toString());
    }
  }

  Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        if (_vapidKey.trim().isEmpty) {
          debugPrint('PushNotificationService: FIREBASE_VAPID_KEY missing; skipping web token registration.');
          return null;
        }
        return await _messaging.getToken(vapidKey: _vapidKey);
      }
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('PushNotificationService: getToken failed err=$e');
      return null;
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  Future<void> _upsertToken({required String userId, required String token}) async {
    try {
      await _client.from('thix_push_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': _platformLabel(),
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
      debugPrint('PushNotificationService: token upserted user=$userId platform=${_platformLabel()}');
    } on PostgrestException catch (e) {
      debugPrint('PushNotificationService: token upsert PostgrestException ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('PushNotificationService: token upsert failed err=$e');
    }
  }

  Future<void> _initLocalNotifications() async {
    // Web doesn't support flutter_local_notifications.
    if (kIsWeb) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(settings: init);

    const channel = AndroidNotificationChannel(
      'thix_general',
      'THIX Notifications',
      description: 'Notifications générales THIX ID',
      importance: Importance.high,
    );
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  Future<void> _configureForegroundHandlers() async {
    try {
      await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    } catch (_) {}

    FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      unawaited(_showForegroundNotification(m));
    });
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;
    try {
      final n = message.notification;
      final title = (n?.title ?? message.data['title']?.toString() ?? 'THIX ID').trim();
      final body = (n?.body ?? message.data['body']?.toString() ?? '').trim();
      if (body.isEmpty && title.isEmpty) return;

      const android = AndroidNotificationDetails(
        'thix_general',
        'THIX Notifications',
        channelDescription: 'Notifications générales THIX ID',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );
      const ios = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      const details = NotificationDetails(android: android, iOS: ios);
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: details,
        payload: message.data.isEmpty ? null : message.data.toString(),
      );
    } catch (e) {
      debugPrint('PushNotificationService: show foreground notification failed err=$e');
    }
  }
}

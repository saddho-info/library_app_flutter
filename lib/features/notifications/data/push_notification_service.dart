import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _available = false;

  bool get isAvailable => _available;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      const channel = AndroidNotificationChannel(
        'pubtrack_notifications',
        'PubTrack notifications',
        description: 'Sales and inventory activity',
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      _available = true;
    } catch (error) {
      // A developer build may intentionally omit Firebase platform config.
      // In-app notifications remain available from the backend.
      debugPrint('Push notifications unavailable: $error');
    }
  }

  Future<String?> requestPermissionAndGetToken() async {
    if (!_available) return null;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return FirebaseMessaging.instance.getToken();
  }

  Stream<String> get tokenRefresh => _available
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream.empty();

  Future<String?> currentToken() async {
    if (!_available) return null;
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: message.messageId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pubtrack_notifications',
          'PubTrack notifications',
          channelDescription: 'Sales and inventory activity',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['notificationId'],
    );
  }
}

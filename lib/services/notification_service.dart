// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ✅ دالة مستقلة لمعالجة الرسالة ليمكن استدعاؤها من عدة أماكن
void _handleMessage(RemoteMessage message) {
  print('رسالة تم التعامل معها: ${message.data}');
  final orderId = message.data['orderId'];
  if (orderId != null) {
    // استخدم خدمة التوجيه للانتقال إلى شاشة تفاصيل الطلب
    // تأكد من أن لديك مسار (route) مناسب في MaterialApp
    // NavigationService.navigatorKey.currentState?.pushNamed('/nurse-order-details', arguments: orderId);
    print("يجب التوجيه إلى شاشة الطلب رقم: $orderId");
  }
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await requestPermission();

    // ✅ التعامل مع الإشعار الذي يفتح التطبيق وهو مغلق
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessage(message);
      }
    });

    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);

    await _localNotificationsPlugin.initialize(initSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 رسالة أثناء foreground: ${message.notification?.title}');
      if (message.notification != null) {
        _showNotification(
          title: message.notification!.title ?? 'إشعار جديد',
          body: message.notification!.body ?? 'لديك رسالة جديدة.',
        );
      }
    });

    // ✅ التعامل مع الإشعار الذي يفتح التطبيق وهو في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  Future<void> requestPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'default_channel_id',
      'Default Channel',
      channelDescription: 'This is the default channel for notifications.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFF6d73ff),
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.toSigned(31),
      title,
      body,
      notificationDetails,
    );
  }

  Future<String?> getFcmToken() async {
    final token = await _firebaseMessaging.getToken();
    print("🔐 FCM Token: $token");
    return token;
  }
}

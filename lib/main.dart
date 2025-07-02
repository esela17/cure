// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cure_app/app.dart';
import 'package:cure_app/firebase_options.dart';
import 'package:cure_app/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';

// صبح صبح يعم الحاج
Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (status.isDenied) {
    await Permission.notification.request();
  }
}

void main() async {
  // التأكد من تهيئة كل شيء قبل تشغيل التطبيق
  WidgetsFlutterBinding.ensureInitialized();

  // ✅✅ إضافة كتلة try-catch لتشخيص مشكلة الشاشة البيضاء ✅✅
  try {
    // 1. تهيئة تنسيق التاريخ (لحل مشكلة LocaleDataException)
    await initializeDateFormatting('ar', null);

    // 2. طلب إذن الإشعارات
    await requestNotificationPermission();

    // 3. تهيئة Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 4. تفعيل Firebase App Check
    // ⚠️ تم تعطيل هذا السطر مؤقتاً لتخطي الخطأ الذي يسبب الشاشة البيضاء.
    // يجب تفعيل هذا الجزء لاحقاً والتأكد من إعدادات Firebase App Check Native
    /*
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug, 
      appleProvider: AppleProvider.appAttest,
    );
    */

    // 5. تهيئة خدمة الإشعارات
    // تأكد من وجود ملف notification_service.dart
    await NotificationService().initialize();

    // 6. تشغيل التطبيق
    runApp(const MyApp());
  } catch (e) {
    // ✅ في حال حدوث خطأ، قم بعرض شاشة خطأ واضحة بدلاً من الشاشة البيضاء
    runApp(ErrorScreen(error: e.toString()));
  }
}

// ✅✅ Widget مساعد لعرض رسالة الخطأ في حال فشل التهيئة (يجب وضعه في نفس الملف) ✅✅
class ErrorScreen extends StatelessWidget {
  final String error;
  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                const Text(
                  'Error Initializing App! \n(خطأ في تهيئة التطبيق/Firebase)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  'Details: \n$error',
                  textAlign: TextAlign.start,
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tip: Run "flutter clean" and check your native Firebase configuration files.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

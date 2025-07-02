// lib/services/navigation_service.dart

import 'package:flutter/material.dart';

class NavigationService {
  // مفتاح عام للوصول إلى حالة الـ Navigator من أي مكان في التطبيق
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // دالة مساعدة (اختيارية) للانتقال إلى شاشة معينة باستخدام اسمها
  static Future<dynamic>? navigateTo(String routeName, {Object? arguments}) {
    // نستخدم المفتاح للوصول إلى الـ Navigator وتنفيذ أمر الانتقال
    return navigatorKey.currentState
        ?.pushNamed(routeName, arguments: arguments);
  }
}

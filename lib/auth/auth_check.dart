// lib/auth/auth_check.dart

import 'package:cure_app/screens/admin_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/screens/home_screen.dart';
import 'package:cure_app/auth/login_screen.dart';
import 'package:cure_app/screens/nurse/nurse_home_screen.dart';
import 'package:cure_app/widgets/loading_indicator.dart';
import 'package:cure_app/widgets/error_message.dart';
import 'package:cure_app/screens/order_tracking_screen.dart';
import 'package:cure_app/widgets/chat_overlay_widget.dart';

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isOverlayVisible = false;

  void _manageChatOverlay(BuildContext context, bool shouldBeVisible) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldBeVisible && !_isOverlayVisible) {
        ChatOverlayManager.show(context);
        if (mounted) {
          setState(() {
            _isOverlayVisible = true;
          });
        }
      } else if (!shouldBeVisible && _isOverlayVisible) {
        ChatOverlayManager.hide();
        if (mounted) {
          setState(() {
            _isOverlayVisible = false;
          });
        }
      }
    });
  }

  Future<String?> _getActiveOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('activeOrderId');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.initialized) {
      return const Scaffold(body: LoadingIndicator());
    }

    if (authProvider.currentUser == null) {
      _manageChatOverlay(context, false);
      return const LoginScreen();
    } else {
      // بعد تسجيل الدخول، أظهر الواجهة فقط إذا كان المستخدم مريضاً
      if (authProvider.currentUserProfile?.role == 'patient') {
        _manageChatOverlay(context, true);
      } else {
        // أخفها للممرض أو الأدوار الأخرى
        _manageChatOverlay(context, false);
      }
    }

    return FutureBuilder<String?>(
      future: _getActiveOrderId(),
      builder: (context, activeOrderSnapshot) {
        if (activeOrderSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingIndicator());
        }

        final activeOrderId = activeOrderSnapshot.data;
        if (activeOrderId != null) {
          return OrderTrackingScreen(orderId: activeOrderId);
        }

        if (authProvider.currentUserProfile == null) {
          if (authProvider.errorMessage != null) {
            return Scaffold(
              body: ErrorMessage(
                message: authProvider.errorMessage!,
                onRetry: () => authProvider.fetchCurrentUserProfile(),
              ),
            );
          }
          return const Scaffold(body: LoadingIndicator());
        }

        // ✅✅ هذا هو التعديل المطلوب: إضافة التحقق من دور الأدمن ✅✅
        final userRole = authProvider.currentUserProfile!.role;

        if (userRole == 'admin') {
          return const AdminHomeScreen();
        } else if (userRole == 'nurse') {
          return const NurseHomeScreen();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}

// lib/app.dart

import 'package:cure_app/providers/chat_provider.dart';
import 'package:cure_app/screens/Terms.dart';
import 'package:cure_app/screens/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Services
import 'package:cure_app/services/auth_service.dart';
import 'package:cure_app/services/firestore_service.dart';
import 'package:cure_app/services/navigation_service.dart';
import 'package:cure_app/services/storage_service.dart';

// Providers
import 'package:cure_app/providers/active_order_provider.dart';
import 'package:cure_app/providers/ads_provider.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/providers/cart_provider.dart';
import 'package:cure_app/providers/categories_provider.dart';
import 'package:cure_app/providers/nurse_provider.dart';
import 'package:cure_app/providers/orders_provider.dart';
import 'package:cure_app/providers/servers_provider.dart';

// Screens
import 'package:cure_app/auth/auth_check.dart';
import 'package:cure_app/auth/login_screen.dart';
import 'package:cure_app/auth/register_screen.dart';
import 'package:cure_app/screens/cart_screen.dart';
import 'package:cure_app/screens/home_screen.dart';
import 'package:cure_app/screens/order_tracking_screen.dart';
import 'package:cure_app/screens/orders_screen.dart';
import 'package:cure_app/screens/profile_screen.dart';
import 'package:cure_app/splash_screen.dart';

// Utils
import 'package:cure_app/utils/constants.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final storageService = StorageService();

    return MultiProvider(
      providers: [
        // Service Providers (not ChangeNotifier)
        Provider<AuthService>(create: (_) => authService),
        Provider<FirestoreService>(create: (_) => firestoreService),
        Provider<StorageService>(create: (_) => storageService),

        // ChangeNotifier Providers
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(authService),
        ),
        ChangeNotifierProvider<ServicesProvider>(
          create: (context) => ServicesProvider(firestoreService),
        ),
        ChangeNotifierProvider<NurseProvider>(
          create: (context) => NurseProvider(firestoreService),
        ),
        ChangeNotifierProvider<AdsProvider>(
          create: (_) => AdsProvider(firestoreService),
        ),
        ChangeNotifierProvider<CategoriesProvider>(
          create: (_) => CategoriesProvider(firestoreService),
        ),
        ChangeNotifierProvider<ActiveOrderProvider>(
          create: (context) =>
              ActiveOrderProvider(context.read<FirestoreService>()),
        ),

        // Proxy Providers (that depend on other providers)
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (context) =>
              CartProvider(firestoreService, context.read<AuthProvider>()),
          update: (context, authProvider, previous) =>
              previous!..updateAuth(authProvider),
        ),
        ChangeNotifierProxyProvider<AuthProvider, OrdersProvider>(
          create: (context) =>
              OrdersProvider(firestoreService, context.read<AuthProvider>()),
          update: (context, authProvider, previous) =>
              previous!..updateAuth(authProvider),
        ),

        // ✅ إضافة الـ Provider الخاص بالمحادثة
        ChangeNotifierProxyProvider2<AuthProvider, ActiveOrderProvider,
            ChatProvider>(
          create: (context) => ChatProvider(
            context.read<AuthProvider>(),
            context.read<ActiveOrderProvider>(),
            context.read<FirestoreService>(),
          ),
          update: (context, authProvider, activeOrderProvider,
                  previousChatProvider) =>
              previousChatProvider!..update(authProvider, activeOrderProvider),
        ),
      ],
      child: MaterialApp(
        // ✅ ربط خدمة التوجيه بالتطبيق
        navigatorKey: NavigationService.navigatorKey,
        title: 'Cure',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: kPrimaryColor,
          hintColor: kAccentColor,
          fontFamily: 'Cairo',
          appBarTheme: const AppBarTheme(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: kPrimaryColor,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrimaryColor, width: 2),
            ),
            labelStyle: const TextStyle(color: Colors.black54),
          ),
        ),
        initialRoute: splashRoute,
        routes: {
          splashRoute: (context) => const SplashScreen(),
          authCheckRoute: (context) => const AuthCheck(),
          loginRoute: (context) => const LoginScreen(),
          registerRoute: (context) => const RegisterScreen(),
          homeRoute: (context) => const HomeScreen(),
          cartRoute: (context) => const CartScreen(),
          ordersRoute: (context) => const OrdersScreen(),
          profileRoute: (context) => const ProfileScreen(),
          editProfileRoute: (context) => const EditProfileScreen(),
          termsRoute: (context) => const TermsScreen(),
          '/order-tracking': (context) {
            final orderId =
                ModalRoute.of(context)!.settings.arguments as String;
            return OrderTrackingScreen(orderId: orderId);
          },
        },
      ),
    );
  }
}

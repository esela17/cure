import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF6d73ff);
const Color kAccentColor = Color(0xFFadfa7d);

const String splashRoute = '/';
const String authCheckRoute = '/authCheck';
const String loginRoute = '/login';
const String registerRoute = '/register';
const String homeRoute = '/home';
const String serviceDetailsRoute = '/serviceDetails';
const String cartRoute = '/cart';
const String checkoutRoute = '/checkout';
const String ordersRoute = '/orders';
const String profileRoute = '/profile';
const String editProfileRoute = '/editProfile';
const String nurseHomeRoute = '/nurseHome';
const String termsRoute = '/terms';

enum ServiceProviderType {
  unspecified,
  nurseMale,
  nurseFemale,
}

extension ServiceProviderTypeExtension on ServiceProviderType {
  String toArabicString() {
    switch (this) {
      case ServiceProviderType.unspecified:
        return 'غير محدد';
      case ServiceProviderType.nurseMale:
        return 'ممرض';
      case ServiceProviderType.nurseFemale:
        return 'ممرضة';
    }
  }
}

import 'package:url_launcher/url_launcher.dart';

/// يحتوي هذا الكلاس على دوال مساعدة ثابتة (static) لإطلاق تطبيقات خارجية.
class CommunicationService {
  /// تطلق تطبيق الهاتف مع رقم محدد.
  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'لا يمكن فتح تطبيق الهاتف.';
    }
  }

  /// تفتح محادثة واتساب مع رقم محدد.
  static Future<void> openWhatsApp({required String phoneNumber}) async {
    // يمكنك إضافة رسالة افتراضية إذا أردت
    // final String encodedMessage = Uri.encodeComponent('مرحباً');
    // final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber?text=$encodedMessage');
    final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'تطبيق واتساب غير مثبت.';
    }
  }

  /// تفتح تطبيق الخرائط على إحداثيات محددة.
  static Future<void> launchMapFromCoordinates(double lat, double lng) async {
    final Uri mapUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'لا يمكن فتح تطبيق الخرائط.';
    }
  }

  /// تفتح تطبيق الخرائط للبحث عن عنوان نصي.
  static Future<void> launchMapFromAddress(String address) async {
    final String encodedAddress = Uri.encodeComponent(address);
    final Uri mapUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'لا يمكن فتح تطبيق الخرائط.';
    }
  }
}

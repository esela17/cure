// lib/utils/constants.dart

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 ألوان التطبيق
// ═══════════════════════════════════════════════════════════════════════════
const Color kPrimaryColor = Color(0xFF6d73ff);
const Color kAccentColor = Color(0xFFadfa7d);
const Color kErrorColor = Color(0xFFf44336);
const Color kWarningColor = Color(0xFFFF9800);
const Color kSuccessColor = Color(0xFF4CAF50);

// ═══════════════════════════════════════════════════════════════════════════
// 🗺️ مسارات التطبيق
// ═══════════════════════════════════════════════════════════════════════════
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
const String transactionHistoryRoute = '/transactionHistory';
const String adminSettlementRoute = '/adminSettlement';

// ═══════════════════════════════════════════════════════════════════════════
// 💳 طرق الدفع
// ═══════════════════════════════════════════════════════════════════════════
const String paymentMethodCash = 'cash';
const String paymentMethodOnline = 'online';

// ═══════════════════════════════════════════════════════════════════════════
// 👨‍⚕️ أنواع مقدمي الخدمة
// ═══════════════════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════════════════
// 📊 حالات الطلب الأساسية (Core Order Status)
// ═══════════════════════════════════════════════════════════════════════════
const String orderStatusPending = 'pending';
const String orderStatusAccepted = 'accepted';
const String orderStatusOnTheWay = 'on_the_way';
const String orderStatusArrived = 'arrived';
const String orderStatusInProgress = 'in_progress';
const String orderStatusCompleted = 'completed';
const String orderStatusRejected = 'rejected';
const String orderStatusCancelled = 'cancelled';
const String orderStatusExpired = 'expired';

// ❌ حالات الإلغاء والرفض (Cancellation & Rejection)
const String orderStatusCancelledByPatient = 'cancelled_by_patient';
const String orderStatusCancelledByNurse = 'cancelled_by_nurse';
const String orderStatusRejectedAtDoor = 'rejected_at_door';
const String orderStatusPatientNotFound = 'patient_not_found';

// 💰 حالات الدفع (Payment Status)
const String orderStatusPaymentPending = 'payment_pending';
const String orderStatusPaymentDispute = 'payment_dispute';
const String orderStatusPartialPayment = 'partial_payment';
const String orderStatusPaymentFailed = 'payment_failed';
const String orderStatusCashConfirmedByPatient = 'cash_confirmed_patient'; // ✅ جديد
const String orderStatusCashConfirmedByNurse = 'cash_confirmed_nurse'; // ✅ جديد

// 🚨 حالات طارئة ونزاعات (Emergency & Disputes)
const String orderStatusEmergency = 'emergency';
const String orderStatusDispute = 'dispute';
const String orderStatusServiceIncomplete = 'service_incomplete';
const String orderStatusComplaint = 'complaint';

// 💸 حالات الاسترداد (Refund Status)
const String orderStatusRefundRequested = 'refund_requested';
const String orderStatusRefunded = 'refunded';

// ═══════════════════════════════════════════════════════════════════════════
// 📋 قوائم أسباب الإلغاء والرفض
// ═══════════════════════════════════════════════════════════════════════════
const List<String> patientCancellationReasons = [
  'تغيير في الخطط',
  'وجدت خيار أفضل',
  'وقت الانتظار طويل',
  'مشكلة في الموقع',
  'مشكلة مع الممرض',
  'لم أعد بحاجة للخدمة',
  'أخرى',
];

const List<String> nurseRejectionReasons = [
  'بعيد جداً',
  'غير متاح في هذا الوقت',
  'لا أقدم هذه الخدمة',
  'مشكلة في الموقع',
  'ظروف شخصية طارئة',
  'أخرى',
];

const List<String> nurseCancellationReasons = [
  'ظروف طارئة',
  'مشكلة في المواصلات',
  'حالة صحية',
  'مشكلة مع المريض',
  'أخرى',
];

const List<String> rejectAtDoorReasons = [
  'المريض رفض الخدمة',
  'الخدمة المطلوبة غير متطابقة',
  'بيئة غير مناسبة للعمل',
  'مشكلة في الأدوات المطلوبة',
  'أخرى',
];

const List<String> incompleteServiceReasons = [
  'المريض رفض إكمال الخدمة',
  'نقص في الأدوات',
  'حالة طارئة',
  'وقت غير كافٍ',
  'أخرى',
];

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 قوائم أسباب عدم الوصول (للممرض)
// ═══════════════════════════════════════════════════════════════════════════
const List<String> notArrivedReasons = [
  'العنوان غير صحيح',
  'المريض غير متواجد',
  'المكان مغلق',
  'مشكلة في الاتصال',
  'سبب آخر',
];

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 دوال الألوان والأيقونات (يجب أن تبقى في Constants لسهولة الوصول)
// ═══════════════════════════════════════════════════════════════════════════

/// الحصول على لون الحالة
Color getOrderStatusColor(String status) {
  switch (status) {
    // حالات إيجابية (نجاح)
    case orderStatusCompleted:
    case orderStatusCashConfirmedByPatient: // ✅ جديد
    case orderStatusCashConfirmedByNurse: // ✅ جديد
      return kSuccessColor;

    // حالات نشطة (قيد التنفيذ)
    case orderStatusAccepted:
    case orderStatusOnTheWay:
    case orderStatusInProgress:
      return kPrimaryColor;

    // حالات انتظار (تحذير)
    case orderStatusPending:
    case orderStatusArrived:
    case orderStatusPaymentPending:
      return kWarningColor;

    // حالات سلبية (رفض/إلغاء)
    case orderStatusRejected:
    case orderStatusCancelled:
    case orderStatusCancelledByPatient:
    case orderStatusCancelledByNurse:
    case orderStatusRejectedAtDoor:
    case orderStatusPatientNotFound:
    case orderStatusPaymentFailed:
    case orderStatusExpired:
      return kErrorColor;

    // حالات نزاعات
    case orderStatusDispute:
    case orderStatusPaymentDispute:
    case orderStatusComplaint:
      return Colors.deepOrange;

    // حالات طارئة
    case orderStatusEmergency:
      return Colors.red.shade900;

    // حالات استرداد
    case orderStatusRefundRequested:
    case orderStatusRefunded:
      return Colors.purple;

    // حالات أخرى
    case orderStatusServiceIncomplete:
    case orderStatusPartialPayment:
      return Colors.grey;

    default:
      return Colors.grey.shade600;
  }
}

/// الحصول على النص العربي للحالة
String getOrderStatusText(String status) {
  switch (status) {
    // حالات أساسية
    case orderStatusPending:
      return 'في انتظار الموافقة';
    case orderStatusAccepted:
      return 'تم القبول';
    case orderStatusOnTheWay:
      return 'في الطريق';
    case orderStatusArrived:
      return 'وصل الممرض';
    case orderStatusInProgress:
      return 'جاري تقديم الخدمة';
    case orderStatusCompleted:
      return 'تم الإنجاز';
    
    // حالات الرفض والإلغاء
    case orderStatusRejected:
      return 'تم الرفض';
    case orderStatusCancelled:
      return 'تم الإلغاء';
    case orderStatusCancelledByPatient:
      return 'ألغاه المريض';
    case orderStatusCancelledByNurse:
      return 'ألغاه الممرض';
    case orderStatusRejectedAtDoor:
      return 'رُفض عند الباب';
    case orderStatusPatientNotFound:
      return 'المريض غير موجود';
    case orderStatusExpired:
      return 'انتهت صلاحيته';
    
    // حالات الدفع
    case orderStatusPaymentPending:
      return 'بانتظار الدفع';
    case orderStatusPaymentDispute:
      return 'نزاع على الدفع';
    case orderStatusPartialPayment:
      return 'دفع جزئي';
    case orderStatusPaymentFailed:
      return 'فشل الدفع';
    case orderStatusCashConfirmedByPatient: // ✅ جديد
      return 'تم تأكيد النقدية من المريض';
    case orderStatusCashConfirmedByNurse: // ✅ جديد
      return 'تم تأكيد النقدية من الممرض';

    // حالات طارئة ونزاعات
    case orderStatusEmergency:
      return 'حالة طارئة';
    case orderStatusDispute:
      return 'نزاع';
    case orderStatusServiceIncomplete:
      return 'خدمة غير مكتملة';
    case orderStatusComplaint:
      return 'شكوى';
    
    // حالات الاسترداد
    case orderStatusRefundRequested:
      return 'طلب استرداد';
    case orderStatusRefunded:
      return 'تم الاسترداد';
    
    default:
      return 'حالة غير معروفة';
  }
}

/// الحصول على أيقونة الحالة
IconData getOrderStatusIcon(String status) {
  switch (status) {
    case orderStatusPending:
      return Icons.pending_actions;
    case orderStatusAccepted:
      return Icons.check_circle;
    case orderStatusOnTheWay:
      return Icons.directions_run;
    case orderStatusArrived:
      return Icons.location_on;
    case orderStatusInProgress:
      return Icons.medical_services;
    case orderStatusCompleted:
      return Icons.task_alt;
    case orderStatusRejected:
    case orderStatusCancelledByPatient:
    case orderStatusCancelledByNurse:
    case orderStatusRejectedAtDoor:
      return Icons.cancel;
    case orderStatusCancelled:
      return Icons.block;
    case orderStatusPatientNotFound:
      return Icons.person_off;
    case orderStatusExpired:
      return Icons.timer_off;
    case orderStatusPaymentPending:
    case orderStatusCashConfirmedByPatient: // ✅ جديد
    case orderStatusCashConfirmedByNurse: // ✅ جديد
      return Icons.payment;
    case orderStatusPaymentDispute:
    case orderStatusDispute:
      return Icons.report_problem;
    case orderStatusPartialPayment:
      return Icons.attach_money;
    case orderStatusPaymentFailed:
      return Icons.error;
    case orderStatusEmergency:
      return Icons.emergency;
    case orderStatusServiceIncomplete:
      return Icons.incomplete_circle;
    case orderStatusComplaint:
      return Icons.feedback;
    case orderStatusRefundRequested:
    case orderStatusRefunded:
      return Icons.money_off;
    default:
      return Icons.help_outline;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ دوال التحقق من الحالة (يجب أن تبقى في Constants لسهولة الوصول)
// ═══════════════════════════════════════════════════════════════════════════

/// هل الطلب قابل للتقييم؟
bool canRateOrder(String status) {
  return status == orderStatusCompleted;
}

/// هل يمكن إلغاء الطلب؟
bool canCancelOrder(String status, {required bool isPatient}) {
  if (isPatient) {
    // المريض يمكنه الإلغاء قبل الوصول فقط
    return [
      orderStatusPending,
      orderStatusAccepted,
      orderStatusOnTheWay,
    ].contains(status);
  } else {
    // الممرض يمكنه الإلغاء بعد القبول وقبل الوصول
    return [
      orderStatusAccepted,
      orderStatusOnTheWay,
    ].contains(status);
  }
}

/// هل الحالة نهائية (لا يمكن تغييرها)؟
bool isTerminalStatus(String status) {
  return [
    orderStatusCompleted,
    orderStatusCancelled,
    orderStatusCancelledByPatient,
    orderStatusCancelledByNurse,
    orderStatusRejected,
    orderStatusRejectedAtDoor,
    orderStatusExpired,
    orderStatusRefunded,
    orderStatusPatientNotFound,
    orderStatusCashConfirmedByPatient, // ✅ جديد
    orderStatusCashConfirmedByNurse, // ✅ جديد
  ].contains(status);
}

/// هل الطلب نشط (قيد التنفيذ)؟
bool isActiveOrder(String status) {
  return [
    orderStatusAccepted,
    orderStatusOnTheWay,
    orderStatusArrived,
    orderStatusInProgress,
  ].contains(status);
}

/// هل الطلب بحاجة لتدخل إداري؟
bool needsAdminIntervention(String status) {
  return [
    orderStatusPaymentDispute,
    orderStatusDispute,
    orderStatusEmergency,
    orderStatusComplaint,
    orderStatusRefundRequested,
    orderStatusServiceIncomplete,
  ].contains(status);
}

// ═══════════════════════════════════════════════════════════════════════════
// ⏭️ الحالات التالية المسموحة
// ═══════════════════════════════════════════════════════════════════════════

/// الحصول على الحالات التالية المسموح بها
List<String> getNextAllowedStatuses(String currentStatus, {required bool isNurse}) {
  if (isNurse) {
    switch (currentStatus) {
      case orderStatusPending:
        return [orderStatusAccepted, orderStatusRejected];
      case orderStatusAccepted:
        return [orderStatusOnTheWay, orderStatusCancelledByNurse];
      case orderStatusOnTheWay:
        return [orderStatusArrived, orderStatusPatientNotFound, orderStatusCancelledByNurse];
      case orderStatusArrived:
        return [orderStatusInProgress, orderStatusRejectedAtDoor];
      case orderStatusInProgress:
        return [
          orderStatusCompleted,
          orderStatusServiceIncomplete,
          orderStatusEmergency,
        ];
      default:
        return [];
    }
  } else {
    // للمريض
    switch (currentStatus) {
      case orderStatusPending:
      case orderStatusAccepted:
      case orderStatusOnTheWay:
        return [orderStatusCancelledByPatient];
      case orderStatusCompleted:
      case orderStatusServiceIncomplete: // يمكن طلب الاسترداد بعد الخدمة غير المكتملة
        return [orderStatusComplaint, orderStatusRefundRequested];
      case orderStatusInProgress:
      case orderStatusArrived:
        return [orderStatusComplaint];
      default:
        return [];
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 📊 معلومات تفصيلية عن الحالة
// ═══════════════════════════════════════════════════════════════════════════

/// الحصول على وصف تفصيلي للحالة
String getOrderStatusDescription(String status) {
  switch (status) {
    case orderStatusPending:
      return 'الطلب في انتظار قبول أحد الممرضين';
    case orderStatusAccepted:
      return 'تم قبول الطلب من قبل الممرض';
    case orderStatusOnTheWay:
      return 'الممرض في الطريق إليك';
    case orderStatusArrived:
      return 'وصل الممرض إلى الموقع';
    case orderStatusInProgress:
      return 'جاري تقديم الخدمة الطبية';
    case orderStatusCompleted:
      return 'تم إنهاء الخدمة بنجاح';
    case orderStatusRejected:
      return 'تم رفض الطلب من قبل الممرض';
    case orderStatusCancelledByPatient:
      return 'قمت بإلغاء الطلب';
    case orderStatusCancelledByNurse:
      return 'ألغى الممرض الطلب';
    case orderStatusRejectedAtDoor:
      return 'تم رفض الخدمة عند الوصول';
    case orderStatusPatientNotFound:
      return 'المريض غير موجود في الموقع المحدد';
    case orderStatusExpired:
      return 'انتهت صلاحية الطلب بسبب عدم الرد';
    case orderStatusPaymentPending:
      return 'في انتظار إتمام عملية الدفع';
    case orderStatusPaymentDispute:
      return 'يوجد نزاع على عملية الدفع';
    case orderStatusPartialPayment:
      return 'تم دفع جزء من المبلغ فقط';
    case orderStatusPaymentFailed:
      return 'فشلت عملية الدفع الإلكتروني';
    case orderStatusCashConfirmedByPatient: // ✅ جديد
      return 'لقد قمت بتأكيد تسليم النقدية للممرض بنجاح.';
    case orderStatusCashConfirmedByNurse: // ✅ جديد
      return 'تم تأكيد استلام النقدية من الممرض بنجاح.';
    case orderStatusEmergency:
      return 'حالة طارئة تحتاج تدخل فوري';
    case orderStatusDispute:
      return 'يوجد نزاع يحتاج تدخل إداري';
    case orderStatusServiceIncomplete:
      return 'لم يتم إكمال الخدمة بشكل كامل';
    case orderStatusComplaint:
      return 'تم تقديم شكوى على الطلب';
    case orderStatusRefundRequested:
      return 'تم طلب استرداد المبلغ';
    case orderStatusRefunded:
      return 'تم استرداد المبلغ بنجاح';
    default:
      return 'حالة غير محددة';
  }
}

/// هل الحالة تستلزم إشعار فوري؟
bool requiresUrgentNotification(String status) {
  return [
    orderStatusEmergency,
    orderStatusPaymentDispute,
    orderStatusPatientNotFound,
    orderStatusRejectedAtDoor,
  ].contains(status);
}

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 دوال مساعدة للدفع النقدي (الميزات الجديدة)
// ═══════════════════════════════════════════════════════════════════════════

/// هل يمكن طلب الدفع النقدي من المريض؟
bool canRequestCashPayment(String status, String paymentMethod) {
  return paymentMethod == paymentMethodCash && 
         status == orderStatusArrived;
}

/// هل يمكن تأكيد استلام النقدية من الممرض؟
bool canConfirmCashReceiptByNurse(String status, String paymentMethod, 
    {bool isCashPaymentRequested = false, bool isPaymentConfirmedByPatient = false}) {
  return paymentMethod == paymentMethodCash && 
         status == orderStatusArrived && 
         isCashPaymentRequested && 
         (isPaymentConfirmedByPatient || true); // يمكن للممرض التأكيد حتى بدون تأكيد المريض
}

/// هل يمكن تأكيد تسليم النقدية من المريض؟
bool canConfirmCashDeliveryByPatient(String status, String paymentMethod, 
    {bool isCashPaymentRequested = false}) {
  return paymentMethod == paymentMethodCash && 
         status == orderStatusArrived && 
         isCashPaymentRequested;
}

/// الحصول على حالة تدفق الدفع النقدي
String getCashPaymentFlowStatus({
  required String paymentMethod,
  required String orderStatus,
  required bool isCashPaymentRequested,
  required bool isPaymentConfirmedByPatient,
  required bool isPaymentConfirmedByNurse,
}) {
  if (paymentMethod != paymentMethodCash) return 'غير نقدي';
  
  if (isPaymentConfirmedByNurse && isPaymentConfirmedByPatient) {
    return 'تم اكتمال الدفع النقدي';
  } else if (isPaymentConfirmedByNurse) {
    return 'بانتظار تأكيد المريض';
  } else if (isPaymentConfirmedByPatient) {
    return 'بانتظار تأكيد الممرض';
  } else if (isCashPaymentRequested) {
    return 'بانتظار تسليم المبلغ';
  } else if (orderStatus == orderStatusArrived) {
    return 'جاهز لطلب الدفع';
  } else {
    return 'غير جاهز للدفع';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 دوال مساعدة للتحرك والتتبع
// ═══════════════════════════════════════════════════════════════════════════

/// هل يمكن للممرض تأكيد التحرك؟
bool canConfirmNurseMoving(String status, {bool isNurseMovingRequested = false}) {
  return status == orderStatusAccepted && isNurseMovingRequested;
}

/// هل يمكن للمريض طلب تأكيد التحرك؟
bool canRequestNurseMovement(String status) {
  return status == orderStatusAccepted;
}

/// هل يمكن للمريض تأكيد رؤية الممرض يتحرك؟
bool canConfirmNurseMovementByPatient(String status, {bool isNurseMovingConfirmed = false}) {
  return status == orderStatusAccepted && isNurseMovingConfirmed;
}

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 دوال مساعدة للعمليات المالية
// ═══════════════════════════════════════════════════════════════════════════

/// حساب قيمة العمولة
double calculateCommission(double finalPrice, double commissionRate) {
  return finalPrice * (commissionRate / 100);
}

/// حساب صافي ربح الممرض
double calculateNurseEarnings(double finalPrice, double commissionRate) {
  return finalPrice - calculateCommission(finalPrice, commissionRate);
}

/// تنسيق المبلغ بالعملة
String formatCurrency(double amount) {
  return '${amount.toStringAsFixed(2)} ج.م';
}

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 ثوابت التطبيق العامة
// ═══════════════════════════════════════════════════════════════════════════

/// وقت المهلة للإلغاء بعد القبول (20 دقيقة)
const Duration cancellationTimeoutDuration = Duration(minutes: 20);

/// الحد الأدنى للمبلغ للدفع الإلكتروني
const double minimumOnlinePaymentAmount = 10.0;

/// نسبة العمولة الافتراضية
const double defaultCommissionRate = 15.0;

/// أنواع الإشعارات
const String notificationTypeOrderUpdate = 'order_update';
const String notificationTypePayment = 'payment';
const String notificationTypeMovement = 'movement';
const String notificationTypeCashRequest = 'cash_request';

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 رسائل التطبيق
// ═══════════════════════════════════════════════════════════════════════════

class AppMessages {
  static const String cashPaymentRequested = 'تم إرسال طلب تسليم المبلغ النقدي للمريض';
  static const String cashPaymentConfirmedByNurse = 'تم تأكيد استلام المبلغ النقدي';
  static const String cashPaymentConfirmedByPatient = 'تم تأكيد تسليم المبلغ النقدي';
  static const String nurseMovementConfirmed = 'تم تأكيد التحرك بنجاح';
  static const String orderCompletedSuccessfully = 'تم إنهاء الخدمة بنجاح';
  static const String orderCancelled = 'تم إلغاء الطلب';
  static const String orderRejected = 'تم رفض الطلب';
  static const String arrivalConfirmed = 'تم تأكيد الوصول بنجاح';
  
  static String earningsAdded(double amount) => 'تم إضافة ${formatCurrency(amount)} إلى رصيدك';
  static String commissionDeducted(double amount) => 'تم خصم ${formatCurrency(amount)} كعمولة للمنصة';
}

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 أخطاء التطبيق
// ═══════════════════════════════════════════════════════════════════════════

class AppErrors {
  static const String networkError = 'حدث خطأ في الاتصال بالإنترنت';
  static const String serverError = 'حدث خطأ في الخادم';
  static const String unknownError = 'حدث خطأ غير متوقع';
  static const String orderNotFound = 'الطلب غير موجود';
  static const String insufficientBalance = 'رصيد غير كافٍ';
  static const String paymentFailed = 'فشلت عملية الدفع';
  static const String locationRequired = 'يجب تحديد الموقع';
  static const String invalidPhoneNumber = 'رقم الهاتف غير صحيح';
}
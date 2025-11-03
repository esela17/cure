// lib/services/discount_service.dart

import 'package:cure_app/services/firestore_service.dart';

class DiscountService {
  final FirestoreService _firestoreService;

  DiscountService(this._firestoreService);

  // ✅ الوظيفة الرئيسية: التحقق من الكوبون وحساب المبلغ النهائي
  // تُستخدم بواسطة CartProvider
  Future<Map<String, double>> applyCoupon(String code, double originalPrice) async {
    
    // 1. التحقق من السعر الأولي
    if (originalPrice <= 0) {
      throw Exception('لا يمكن تطبيق الكوبون على طلب بقيمة صفر.');
    }

    // 2. التحقق من صلاحية الكوبون عبر Firestore Service
    // نستخدم الدالة التي أضفناها (validateCouponCode)
    final coupon = await _firestoreService.validateCouponCode(code);

    if (coupon == null) {
      throw Exception('كود الخصم غير صالح، غير نشط، أو منتهي الصلاحية.');
    }

    // 3. التحقق من الحد الأدنى للطلب
    if (originalPrice < coupon.minOrderAmount) {
      throw Exception('الحد الأدنى للطلب لهذا الكوبون هو ${coupon.minOrderAmount.toStringAsFixed(2)} جنيه.');
    }
    
    double discountAmount = 0.0;

    // 4. حساب الخصم
    if (coupon.type == 'percentage') {
      // ✅ استخدام حقل 'value' (الذي يمثل النسبة)
      discountAmount = (originalPrice * (coupon.value / 100.0));
    } else if (coupon.type == 'fixed') {
      // ✅ استخدام حقل 'value' (الذي يمثل القيمة الثابتة)
      discountAmount = coupon.value;
    }
    
    // 5. ضمان أن الخصم لا يتجاوز قيمة الطلب
    discountAmount = discountAmount.clamp(0.0, originalPrice);

    final finalPrice = originalPrice - discountAmount;

    // 6. إرجاع النتيجة
    return {
      'discountAmount': discountAmount,
      'finalPrice': finalPrice,
    };
  }
}
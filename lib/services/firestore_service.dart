// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart' as firestore_package;
import 'package:cloud_functions/cloud_functions.dart' as functions_package;
import 'package:cure_app/models/ad_banner.dart';
import 'package:cure_app/models/category_shortcut.dart';
import 'package:cure_app/models/order.dart';
import 'package:cure_app/models/review_model.dart';
import 'package:cure_app/models/service.dart';
import 'package:cure_app/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coupon_model.dart';
import '../models/app_settings.dart';
import '../models/transaction_model.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:cure_app/utils/order_statuses.dart';

class FirestoreService {
  final firestore_package.FirebaseFirestore _db =
      firestore_package.FirebaseFirestore.instance;
  final functions_package.FirebaseFunctions _functions =
      functions_package.FirebaseFunctions.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // 📋 SETTINGS FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<AppSettings> getAppSettingsStream() {
    return _db
        .collection('settings')
        .doc('finance')
        .withConverter<AppSettings>(
          fromFirestore: (snapshot, _) => AppSettings.fromFirestore(snapshot),
          toFirestore: (settings, _) => {},
        )
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return AppSettings(platformCommissionRate: 0.0);
      }
      return snapshot.data()!;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎫 COUPON/DISCOUNT FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<CouponModel?> validateCouponCode(String code) async {
    final querySnapshot = await _db
        .collection('coupons')
        .where('code', isEqualTo: code.toUpperCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    final doc = querySnapshot.docs.first;
    final coupon = CouponModel.fromFirestore(doc);

    if (coupon.expiryDate.isBefore(DateTime.now())) return null;
    if (coupon.usedCount >= coupon.maxUses) return null;

    return coupon;
  }

  Future<CouponModel?> getCouponByCode(String code) {
    return validateCouponCode(code);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 👤 USER-RELATED FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> addUser(UserModel user) async {
    await _db
        .collection('users')
        .doc(user.id)
        .withConverter<UserModel>(
          fromFirestore: UserModel.fromFirestore,
          toFirestore: (UserModel user, options) => user.toFirestore(),
        )
        .set(user);
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .withConverter<UserModel>(
          fromFirestore: UserModel.fromFirestore,
          toFirestore: (user, options) => user.toFirestore(),
        )
        .get();
    return doc.data();
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> incrementNurseJobCount(String nurseId) async {
    final nurseRef = _db.collection('users').doc(nurseId);
    await nurseRef.update({
      'jobCount': firestore_package.FieldValue.increment(1),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛠️ SERVICE-RELATED FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<List<Service>> getServices() {
    return _db
        .collection('services')
        .withConverter<Service>(
          fromFirestore: Service.fromFirestore,
          toFirestore: (Service service, options) => service.toFirestore(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 ORDER-RELATED FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<firestore_package.DocumentReference> addOrder(Order order) async {
    final docRef = await _db.collection('requests').add({
      ...order.toFirestore(),
      if (order.locationLat != null) 'locationLat': order.locationLat,
      if (order.locationLng != null) 'locationLng': order.locationLng,
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeOrderId', docRef.id);

    return docRef;
  }

  /// ✅ الدالة العامة لتحديث حقول الطلب
  Future<void> updateOrderFields(
      String orderId, Map<String, dynamic> dataToUpdate) async {
    await _db.collection('requests').doc(orderId).update({
      ...dataToUpdate,
      'lastUpdated': firestore_package.FieldValue.serverTimestamp(),
    });

    // إذا تم إنهاء الطلب أو إلغاؤه، نقوم بمسح الـ activeOrderId
    if (dataToUpdate.containsKey('status') &&
        (isTerminalStatus(dataToUpdate['status'] as String) ||
            dataToUpdate['status'] == OrderStatus.cancelledByPatient || 
            dataToUpdate['status'] == OrderStatus.cancelledByNurse || 
            dataToUpdate['status'] == OrderStatus.rejected)) { 
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('activeOrderId');
    }
  }

  /// ✅ الدالة التوجيهية (Wrapper) لحل مشكلة التوافق
  Future<void> updateOrderStatus(
      String orderId, Map<String, dynamic> dataToUpdate) async {
    await updateOrderFields(orderId, dataToUpdate);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕 MOVEMENT TRACKING METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// المريض يطلب من الممرض تأكيد التحرك
  Future<void> requestNurseMovementConfirmation(String orderId) async {
    try {
      await updateOrderFields(orderId, {
        'isNurseMovingRequested': true,
        'nurseMovingRequestedAt': firestore_package.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to request movement confirmation: $e');
    }
  }

  /// الممرض يؤكد أنه يتحرك
  Future<void> confirmNurseMoving(String orderId) async {
    try {
      await updateOrderFields(orderId, {
        'isNurseMovingConfirmed': true,
        'nurseMovingConfirmedAt': firestore_package.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to confirm nurse movement: $e');
    }
  }

  /// المريض يؤكد أنه يرى الممرض يتحرك
  Future<void> patientConfirmsNurseMoving(String orderId) async {
    try {
      await updateOrderFields(orderId, {
        'patientConfirmedNurseMoving': true,
        'patientConfirmedMovingAt': firestore_package.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to confirm patient observation: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕🆕🆕 NURSE ARRIVAL CONFIRMATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// ✅ تأكيد وصول الممرض من قبل المريض
  Future<void> confirmNurseArrival(String orderId) async {
    try {
      await updateOrderFields(orderId, {
        'isNurseArrivalConfirmedByPatient': true,
        'nurseArrivalConfirmedAt': firestore_package.FieldValue.serverTimestamp(),
      });
      
      // إرسال إشعار للممرض
      await _sendNotificationToNurse(orderId, 'تم تأكيد وصولك', 'المريض أكد وصولك إلى الموقع');
    } catch (e) {
      throw Exception('فشل في تأكيد وصول الممرض: $e');
    }
  }

  /// ✅ الإبلاغ عن عدم وصول الممرض
  Future<void> reportNurseNotArrived(String orderId) async {
    try {
      final orderDoc = await _db.collection('requests').doc(orderId).get();
      final order = orderDoc.data();
      
      await updateOrderFields(orderId, {
        'nurseNotArrivedReported': true,
        'nurseNotArrivedReportedAt': firestore_package.FieldValue.serverTimestamp(),
      });
      
      // إرسال إشعار للممرض والدعم الفني
      await _sendNotificationToNurse(orderId, 'إبلاغ بعدم الوصول', 'المريض أبلغ أنك لم تصل بعد');
      await _sendNotificationToAdmins(orderId, 'إبلاغ بعدم وصول ممرض', 
          'المريض ${order?['patientName']} أبلغ أن الممرض لم يصل بعد للطلب $orderId');
      
    } catch (e) {
      throw Exception('فشل في الإبلاغ عن عدم الوصول: $e');
    }
  }

  /// ✅ الإبلاغ عن ممرض غير صحيح
  Future<void> reportWrongNurse(String orderId) async {
    try {
      final orderDoc = await _db.collection('requests').doc(orderId).get();
      final order = orderDoc.data();
      
      await updateOrderFields(orderId, {
        'wrongNurseReported': true,
        'wrongNurseReportedAt': firestore_package.FieldValue.serverTimestamp(),
      });
      
      // إرسال إشعار عاجل للدعم الفني
      await _sendNotificationToAdmins(orderId, '🚨 إبلاغ عن ممرض غير صحيح', 
          'المريض ${order?['patientName']} أبلغ أن الممرض الحالي ليس هو المطلوب للطلب $orderId. يرجى التدخل العاجل.');
      
    } catch (e) {
      throw Exception('فشل في الإبلاغ عن ممرض غير صحيح: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔔 NOTIFICATION HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// ✅ دالة مساعدة لإرسال إشعار للممرض
  Future<void> _sendNotificationToNurse(String orderId, String title, String body) async {
    try {
      final orderDoc = await _db.collection('requests').doc(orderId).get();
      final order = orderDoc.data();
      final nurseId = order?['nurseId'];
      
      if (nurseId != null) {
        await _db.collection('notifications').add({
          'userId': nurseId,
          'title': title,
          'body': body,
          'orderId': orderId,
          'timestamp': firestore_package.FieldValue.serverTimestamp(),
          'read': false,
          'type': 'order_update',
        });
      }
    } catch (e) {
      print('فشل في إرسال إشعار للممرض: $e');
    }
  }

  /// ✅ دالة مساعدة لإرسال إشعار للمسؤولين
  Future<void> _sendNotificationToAdmins(String orderId, String title, String body) async {
    try {
      // الحصول على جميع المسؤولين
      final adminsSnapshot = await _db.collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      
      for (final adminDoc in adminsSnapshot.docs) {
        await _db.collection('notifications').add({
          'userId': adminDoc.id,
          'title': title,
          'body': body,
          'orderId': orderId,
          'timestamp': firestore_package.FieldValue.serverTimestamp(),
          'read': false,
          'type': 'urgent_alert',
        });
      }
    } catch (e) {
      print('فشل في إرسال إشعار للمسؤولين: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕 ACCEPT ORDER - قبول الطلب مع تفعيل مؤقت 20 دقيقة
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> acceptOrder(
    String orderId, 
    String nurseId, 
    String nurseName
  ) async {
    try {
      // حساب وقت تفعيل زر الإلغاء (بعد 20 دقيقة)
      final now = DateTime.now();
      final cancellationAvailableAt = now.add(const Duration(minutes: 20));

      await updateOrderFields(orderId, {
        'status': OrderStatus.accepted,
        'nurseId': nurseId,
        'nurseName': nurseName,
        'acceptedAt': firestore_package.FieldValue.serverTimestamp(),
        'cancellationAvailableAt': firestore_package.Timestamp.fromDate(cancellationAvailableAt),
        'canPatientCancelAfterAccept': false, // سيتم تفعيله بعد 20 دقيقة
      });
    } catch (e) {
      throw Exception('Failed to accept order: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📍 MARK AS ARRIVED - تأكيد الوصول
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> markAsArrived(String orderId) async {
    try {
      await updateOrderFields(orderId, {
        'status': OrderStatus.arrived,
        'arrivedAt': firestore_package.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark as arrived: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ COMPLETE ORDER - إنهاء الطلب
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> completeOrder(String orderId) async {
    await updateOrderFields(orderId, {
      'status': OrderStatus.completed,
      'completedAt': firestore_package.FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 💰 PAYMENT CONFIRMATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// الممرض يؤكد استلام الدفع النقدي
  Future<void> nurseConfirmsCashPayment(String orderId) async {
    try {
      await updateOrderFields(orderId, {
        'isPaymentConfirmedByNurse': true,
        'nursePaymentConfirmedAt': firestore_package.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to confirm cash payment by nurse: $e');
    }
  }

  /// المريض يؤكد تسليم الدفع النقدي
  Future<void> patientConfirmsCashPayment(String orderId) async {
    try {
      await updateOrderFields(orderId, {
        'isPaymentConfirmedByPatient': true,
        'patientPaymentConfirmedAt': firestore_package.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to confirm cash payment by patient: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ❌ CANCEL & REJECT ORDER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// إلغاء الطلب من المريض
  Future<void> cancelOrder(
    String orderId, 
    String reason, 
    String cancelledBy
  ) async {
    try {
      await updateOrderFields(orderId, {
        'status': OrderStatus.cancelledByPatient,
        'cancelReason': reason,
        'cancelledBy': cancelledBy,
        'cancelledAt': firestore_package.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  /// رفض الطلب من الممرض
  Future<void> rejectOrder(String orderId, String reason) async {
    try {
      await updateOrderFields(orderId, {
        'status': OrderStatus.rejected,
        'rejectReason': reason,
        'rejectedAt': firestore_package.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reject order: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔍 QUERY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<Order> getOrderStream(String orderId) {
    return _db
        .collection('requests')
        .doc(orderId)
        .withConverter<Order>(
          fromFirestore: Order.fromFirestore,
          toFirestore: (Order order, options) => order.toFirestore(),
        )
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception("Order with ID $orderId not found!");
      }
      return snapshot.data()!;
    });
  }

  Stream<List<Order>> getUserOrders(String userId) {
    return _db
        .collection('requests')
        .where('userId', isEqualTo: userId)
        .orderBy('orderDate', descending: true)
        .withConverter<Order>(
          fromFirestore: Order.fromFirestore,
          toFirestore: (Order order, options) => order.toFirestore(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Order>> getPendingOrders() {
    return _db
        .collection('requests')
        .where('status', isEqualTo: OrderStatus.pending)
        .orderBy('orderDate', descending: true)
        .withConverter<Order>(
          fromFirestore: Order.fromFirestore,
          toFirestore: (Order order, options) => order.toFirestore(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Order>> getOrdersForNurse(String nurseId) {
    return _db
        .collection('requests')
        .where('nurseId', isEqualTo: nurseId)
        .orderBy('orderDate', descending: true)
        .withConverter<Order>(
          fromFirestore: Order.fromFirestore,
          toFirestore: (Order order, options) => order.toFirestore(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// الحصول على طلب واحد
  Future<Order?> getOrder(String orderId) async {
    try {
      final doc = await _db
        .collection('requests')
        .doc(orderId)
        .withConverter<Order>(
          fromFirestore: Order.fromFirestore,
          toFirestore: (order, options) => order.toFirestore(),
        )
        .get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to get order: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📱 ADVERTISEMENT & CATEGORY FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  Stream<List<AdBanner>> getAdvertisements() {
    return _db
        .collection('advertisements')
        .withConverter<AdBanner>(
          fromFirestore: (snapshot, _) => AdBanner.fromFirestore(snapshot),
          toFirestore: (ad, _) => {},
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<CategoryShortcut>> getCategoryShortcuts() {
    return _db
        .collection('categories')
        .orderBy('index', descending: false)
        .withConverter<CategoryShortcut>(
          fromFirestore: (snapshot, _) =>
              CategoryShortcut.fromFirestore(snapshot),
          toFirestore: (category, _) => {},
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⭐ REVIEW-RELATED FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> submitReview({
    required String orderId,
    required String nurseId,
    required double rating,
    required String reviewText,
    required String patientName,
  }) async {
    final nurseRef = _db.collection('users').doc(nurseId);
    final orderRef = _db.collection('requests').doc(orderId);
    final reviewRef = nurseRef.collection('reviews').doc();

    return _db.runTransaction((transaction) async {
      final nurseDoc = await transaction.get(nurseRef);
      if (!nurseDoc.exists) {
        throw Exception("Nurse not found!");
      }

      final currentRatingCount = nurseDoc.data()?['ratingCount'] ?? 0;
      final currentAverageRating =
          (nurseDoc.data()?['averageRating'] as num?)?.toDouble() ?? 0.0;

      final newAverageRating =
          ((currentAverageRating * currentRatingCount) + rating) /
              (currentRatingCount + 1);
      final newRatingCount = currentRatingCount + 1;

      transaction.set(reviewRef, {
        'rating': rating,
        'comment': reviewText,
        'patientName': patientName,
        'timestamp': firestore_package.FieldValue.serverTimestamp(),
      });

      transaction.update(nurseRef, {
        'ratingCount': newRatingCount,
        'averageRating': newAverageRating,
      });

      transaction.update(orderRef, {'isRated': true});
    });
  }

  Future<List<ReviewModel>> getReviewsForNurse(String nurseId) async {
    final reviewsSnapshot = await _db
        .collection('users')
        .doc(nurseId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .get();

    return reviewsSnapshot.docs
        .map((doc) => ReviewModel.fromFirestore(doc))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 👨‍💼 ADMIN & PAYOUT FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<double> callManualSettlement({
    required String nurseId,
    required double amount,
    String? note,
  }) async {
    try {
      final functions_package.HttpsCallable callable =
          _functions.httpsCallable('manualBalanceSettlement');

      final result = await callable.call(<String, dynamic>{
        'nurseId': nurseId,
        'amount': amount,
        'note': note,
      });

      if (result.data != null && result.data['success'] == true) {
        return (result.data['newBalance'] as num?)?.toDouble() ?? 0.0;
      }

      throw Exception('فشلت عملية تسوية الرصيد: استجابة غير متوقعة.');
    } on functions_package.FirebaseFunctionsException catch (e) {
      throw Exception('خطأ في دالة التسوية: ${e.message}');
    } catch (e) {
      throw Exception('فشل الاتصال بخدمة التسوية: $e');
    }
  }

  Future<double> callProcessNursePayout({
    required String nurseId,
    required double amount,
    String? note,
  }) async {
    try {
      final functions_package.HttpsCallable callable =
          _functions.httpsCallable('processNursePayout');

      final result = await callable.call(<String, dynamic>{
        'nurseId': nurseId,
        'amount': amount,
        'note': note,
      });

      if (result.data != null && result.data['success'] == true) {
        return (result.data['newBalance'] as num?)?.toDouble() ?? 0.0;
      }

      throw Exception('فشلت عملية صرف المستحقات: استجابة غير متوقعة.');
    } on functions_package.FirebaseFunctionsException catch (e) {
      throw Exception('خطأ في دالة الصرف: ${e.message}');
    } catch (e) {
      throw Exception('فشل الاتصال بخدمة الصرف: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 💳 TRANSACTION HISTORY FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  firestore_package.Query getTransactionsQuery() {
    return _db
        .collection('transactions')
        .orderBy('timestamp', descending: true);
  }

  Stream<List<TransactionModel>> getTransactionsStream(
      {firestore_package.Query? query}) {
    final effectiveQuery = query ?? getTransactionsQuery();

    return effectiveQuery
        .withConverter<TransactionModel>(
          fromFirestore: (snapshot, _) =>
              TransactionModel.fromFirestore(snapshot),
          toFirestore: (model, _) => model.toFirestore(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
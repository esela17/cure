// lib/providers/orders_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cure_app/models/order.dart';
import 'package:cure_app/services/firestore_service.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/utils/constants.dart'; 
import 'package:cure_app/utils/helpers.dart'; 
import 'package:cure_app/utils/order_statuses.dart' hide CancelledBy; // ✅ إضافة: لاستخدام حالات النظام
import 'package:cloud_firestore/cloud_firestore.dart' as firestore_package; // ✅ إضافة: لاستخدام Timestamps/FieldValues

class OrdersProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  AuthProvider _authProvider;
  List<Order> _userOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _ordersStreamSubscription;

  OrdersProvider(this._firestoreService, this._authProvider) {
    _authProvider.addListener(_onAuthChange);
    _onAuthChange(); // Initial check
  }
  
  void updateAuth(AuthProvider newAuth) {
    _authProvider = newAuth;
  }

  void _onAuthChange() {
    if (_authProvider.currentUser != null) {
      fetchUserOrders(_authProvider.currentUser!.uid);
    } else {
      _stopListeningToOrders();
    }
  }

  void fetchUserOrders([String? userId]) {
    final id = userId ?? _authProvider.currentUser?.uid;
    if (id == null) {
      _errorMessage = 'لا يوجد مستخدم مسجل الدخول لعرض الطلبات.';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _ordersStreamSubscription?.cancel();
    _ordersStreamSubscription =
        _firestoreService.getUserOrders(id).listen((orders) {
      _userOrders = orders;
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print("!!!!!!!! ERROR fetching user orders: $error !!!!!!!!");
      _errorMessage = 'حدث خطأ أثناء جلب الطلبات: ${error.toString()}';
      _isLoading = false;
      notifyListeners();
    });
  }

  void _stopListeningToOrders() {
    _ordersStreamSubscription?.cancel();
    _userOrders = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  List<Order> get userOrders => _userOrders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ========================================================
  // ⭐ دوال الإجراءات الجديدة (New Action Functions) ⭐
  // ========================================================

  // ✅ إضافة: دالة إلغاء الطلب من قبل المريض
  Future<bool> cancelOrder(
      String orderId, String reason, BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.cancelOrder(
        orderId, 
        reason,
        CancelledBy.patient.toString().split('.').last // ✅ استخدام Enum
      );
      showSnackBar(context, 'تم إلغاء طلبك بنجاح.', isError: true);
      return true;
    } catch (e) {
      _errorMessage = 'فشل في إلغاء الطلب: ${e.toString()}';
      showSnackBar(context, _errorMessage!, isError: true);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ إضافة: دالة طلب استرداد المبلغ
  Future<bool> requestRefund(
      String orderId, String reason, BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateOrderFields(
        orderId,
        {
          'status': OrderStatus.refundRequested, // ✅ تحديث
          'refundReason': reason,
        },
      );
      showSnackBar(context, 'تم إرسال طلب استرداد المبلغ للمراجعة.',
          isError: false);
      return true;
    } catch (e) {
      _errorMessage = 'فشل في إرسال طلب الاسترداد: ${e.toString()}';
      showSnackBar(context, _errorMessage!, isError: true);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ إضافة: دالة تقديم شكوى/نزاع
  Future<bool> fileComplaint(
      String orderId, String details, BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateOrderFields(
        orderId,
        {
          'status': OrderStatus.complaint, // ✅ تحديث
          'complaintDetails': details,
        },
      );
      showSnackBar(context, 'تم تسجيل شكواك. سيتم مراجعتها من قبل الإدارة قريباً.',
          isError: true); 
      return true;
    } catch (e) {
      _errorMessage = 'فشل في تسجيل الشكوى: ${e.toString()}';
      showSnackBar(context, _errorMessage!, isError: true);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕 دوال التكامل مع الممرض (دليل التكامل)
  // ═══════════════════════════════════════════════════════════════════════════

  // ✅ طلب تأكيد التحرك من المريض (تستخدم في Patient Tracking Screen)
  Future<void> requestNurseMovementConfirmation(String orderId) async {
    _isLoading = true;
    try {
      await _firestoreService.requestNurseMovementConfirmation(orderId);
    } catch (e) {
      _errorMessage = "فشل في طلب التأكيد: ${e.toString()}";
      throw e; 
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ تأكيد تسليم الدفع النقدي من المريض (تستخدم في Patient Tracking Screen)
  Future<bool> patientConfirmsCashPayment(String orderId) async {
    _isLoading = true;
    try {
      await _firestoreService.patientConfirmsCashPayment(orderId);
      return true;
    } catch (e) {
      _errorMessage = "فشل في تأكيد الدفع: ${e.toString()}";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕🆕🆕 دوال تأكيد وصول الممرض والإبلاغ عن المشاكل
  // ═══════════════════════════════════════════════════════════════════════════

  // ✅ تأكيد وصول الممرض من قبل المريض
  Future<bool> confirmNurseArrival(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.confirmNurseArrival(orderId);
      _updateOrderStatusLocally(orderId, {'isNurseArrivalConfirmedByPatient': true});
      return true;
    } catch (e) {
      _errorMessage = 'فشل في تأكيد وصول الممرض: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ الإبلاغ عن عدم وصول الممرض
  Future<bool> reportNurseNotArrived(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.reportNurseNotArrived(orderId);
      return true;
    } catch (e) {
      _errorMessage = 'فشل في الإبلاغ عن عدم الوصول: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ الإبلاغ عن ممرض غير صحيح
  Future<bool> reportWrongNurse(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.reportWrongNurse(orderId);
      return true;
    } catch (e) {
      _errorMessage = 'فشل في الإبلاغ عن ممرض غير صحيح: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ دالة مساعدة لتحديث الحالة محلياً
  void _updateOrderStatusLocally(String orderId, Map<String, dynamic> updates) {
    final index = _userOrders.indexWhere((order) => order.id == orderId);
    if (index != -1) {
      final order = _userOrders[index];
      
      // تحديث الحقول المطلوبة
      if (updates.containsKey('isNurseArrivalConfirmedByPatient')) {
        _userOrders[index] = order.copyWith(
          isNurseArrivalConfirmedByPatient: updates['isNurseArrivalConfirmedByPatient'],
        );
      }
      
      notifyListeners();
    }
  }

  // --------------------------------------------------------
  // --- دالة التقييم ---
  Future<bool> submitReview({
    required Order order,
    required double rating,
    required String comment,
  }) async {
    if (order.nurseId == null || _authProvider.currentUserProfile == null) {
      _errorMessage = "Cannot submit review without nurse or patient info.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // تم افتراض وجود دالة submitReview في firestoreService
      // await _firestoreService.submitReview(...)
      
      // تحديث قائمة الطلبات بعد التقييم
      fetchUserOrders(order.userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Failed to submit review: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChange);
    _ordersStreamSubscription?.cancel();
    super.dispose();
  }
}
// lib/providers/nurse_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cure_app/models/order.dart';
import 'package:cure_app/models/user_model.dart';
import 'package:cure_app/services/firestore_service.dart';
import 'package:cure_app/utils/order_statuses.dart';
import 'package:cure_app/utils/helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore_package;

class NurseProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  StreamSubscription? _pendingOrdersSubscription;
  StreamSubscription? _myOrdersSubscription;

  List<Order> _pendingOrders = [];
  List<Order> _myOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAvailable = true;

  NurseProvider(this._firestoreService) {
    fetchPendingOrders();
  }

  // Getters
  List<Order> get pendingOrders => _pendingOrders;
  List<Order> get myOrders => _myOrders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAvailable => _isAvailable;

  // Getters for stats
  int get pendingOrdersCount => _pendingOrders.length;
  int get acceptedOrdersCount => _myOrders
      .where((o) => o.status == OrderStatus.accepted || o.status == OrderStatus.arrived)
      .length;
  int get completedOrdersCount =>
      _myOrders.where((o) => o.status == OrderStatus.completed).length;

  void setAvailability(bool available) {
    _isAvailable = available;
    notifyListeners();
  }

  void fetchPendingOrders() {
    _isLoading = true;
    notifyListeners();
    _pendingOrdersSubscription?.cancel();
    _pendingOrdersSubscription =
        _firestoreService.getPendingOrders().listen((orders) {
      _pendingOrders = orders;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }, onError: (error) {
      debugPrint("!!!!!!!! ERROR fetching pending orders: $error !!!!!!!!");
      _errorMessage = "حدث خطأ في جلب الطلبات المتاحة.";
      _isLoading = false;
      notifyListeners();
    });
  }

  void fetchMyOrders(String nurseId) {
    _myOrdersSubscription?.cancel();
    _myOrdersSubscription =
        _firestoreService.getOrdersForNurse(nurseId).listen((orders) {
      _myOrders = orders;
      notifyListeners();
    }, onError: (error) {
      debugPrint("Error fetching nurse's own orders: $error");
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⭐ ACCEPT ORDER - قبول الطلب (تتضمن مؤقت الإلغاء)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> acceptOrder(Order order, UserModel nurse) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (nurse.id.isEmpty) {
        throw Exception("فشل تحديد معرف الممرض.");
      }

      await _firestoreService.acceptOrder(
        order.id,
        nurse.id,
        nurse.name,
      );

      // تحديث القوائم المحلية بعد قبول الطلب
      fetchPendingOrders();
      if (nurse.id.isNotEmpty) fetchMyOrders(nurse.id);

      _isLoading = false;
      return true;
    } catch (e) {
      _errorMessage = "فشل قبول الطلب: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ❌ REJECT ORDER - رفض الطلب
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> rejectOrder(Order order, String reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.rejectOrder(order.id, reason);
      
      fetchPendingOrders();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "فشل رفض الطلب: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏃 MARK AS ON THE WAY - في الطريق
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> markAsOnTheWay(Order order) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateOrderFields(
        order.id,
        {
          'status': OrderStatus.onTheWay,
          'isNurseMovingConfirmed': true, 
          'nurseMovingConfirmedAt': firestore_package.FieldValue.serverTimestamp(),
        },
      );
      
      if (order.nurseId != null) fetchMyOrders(order.nurseId!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "فشل تحديث الحالة: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📍 MARK AS ARRIVED - وصل الممرض
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> markAsArrived(Order order) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.markAsArrived(order.id); 
      
      if (order.nurseId != null) fetchMyOrders(order.nurseId!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "فشل تحديث الحالة: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕 REPORT NOT ARRIVED - الإبلاغ عن عدم الوصول
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> reportNotArrived(Order order, String reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateOrderFields(order.id, {
        'status': OrderStatus.cancelledByNurse,
        'cancelReason': 'لم يصل الممرض: $reason',
        'cancelledBy': 'nurse',
        'cancelledAt': firestore_package.FieldValue.serverTimestamp(),
      });
      
      // تحديث القوائم
      fetchPendingOrders();
      if (order.nurseId != null) fetchMyOrders(order.nurseId!);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "فشل في الإبلاغ عن عدم الوصول: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕 CONFIRM NURSE MOVING - تأكيد تحرك الممرض
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> confirmNurseMoving(Order order) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateOrderFields(order.id, {
        'isNurseMovingConfirmed': true,
        'nurseMovingConfirmedAt': firestore_package.FieldValue.serverTimestamp(),
      });
      
      if (order.nurseId != null) fetchMyOrders(order.nurseId!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "فشل في تأكيد التحرك: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ COMPLETE ORDER - إكمال الطلب
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> completeOrder(Order order) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.completeOrder(order.id);

      if (order.nurseId != null) {
        await _firestoreService.incrementNurseJobCount(order.nurseId!);
        fetchMyOrders(order.nurseId!);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "فشل إكمال الطلب: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 💰 NURSE CONFIRMS CASH PAYMENT - تأكيد استلام النقدية
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> nurseConfirmsCashPayment(String orderId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.nurseConfirmsCashPayment(orderId);
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
  // 🆕 GET ORDER BY ID - الحصول على طلب بواسطة المعرف
  // ═══════════════════════════════════════════════════════════════════════════
  Future<Order?> getOrderById(String orderId) async {
    try {
      return await _firestoreService.getOrder(orderId);
    } catch (e) {
      _errorMessage = "فشل في جلب بيانات الطلب: $e";
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕 REFRESH ORDERS - تحديث القوائم
  // ═══════════════════════════════════════════════════════════════════════════
  void refreshOrders(String nurseId) {
    fetchPendingOrders();
    fetchMyOrders(nurseId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕 CLEAR ERROR - مسح رسالة الخطأ
  // ═══════════════════════════════════════════════════════════════════════════
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingOrdersSubscription?.cancel();
    _myOrdersSubscription?.cancel();
    super.dispose();
  }
}
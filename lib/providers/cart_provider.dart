// lib/providers/cart_provider.dart

import 'package:flutter/material.dart';
import 'package:cure_app/models/order.dart';
import 'package:cure_app/models/service.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/services/firestore_service.dart';
import 'package:cure_app/services/discount_service.dart'; 
import 'package:cure_app/utils/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cure_app/providers/settings_provider.dart'; 
import 'package:cure_app/utils/constants.dart';
import 'package:cure_app/models/coupon_model.dart'; 


class CartProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final DiscountService _discountService;
  AuthProvider _authProvider;
  
  SettingsProvider? _settingsProvider; 

  CartProvider(
      this._firestoreService,
      this._authProvider,
      this._discountService,
      );

  // -------------------------------
  // 🧾 متغيرات داخلية (State Variables)
  // -------------------------------
  final List<Service> _cartItems = [];
  DateTime? _selectedAppointmentDate;
  String _notes = '';
  bool _isPlacingOrder = false; // ✅ تم تعريفه الآن
  String? _orderErrorMessage;
  String _serviceProviderType = 'غير محدد';
  double? _selectedLat;
  double? _selectedLng;

  // 🎁 متغيرات الكوبون
  String? _appliedCouponCode;
  double _currentDiscountAmount = 0.0;
  double _finalPrice = 0.0;

  // -------------------------------
  // 🧠 Getters
  // -------------------------------
  List<Service> get cartItems => _cartItems;
  DateTime? get selectedAppointmentDate => _selectedAppointmentDate;
  String get notes => _notes;
  bool get isPlacingOrder => _isPlacingOrder; // ✅ Getter تم تعريفه الآن
  String? get orderErrorMessage => _orderErrorMessage;
  String get serviceProviderType => _serviceProviderType;
  double? get selectedLat => _selectedLat;
  double? get selectedLng => _selectedLng;

  String? get appliedCouponCode => _appliedCouponCode;
  double get currentDiscountAmount => _currentDiscountAmount;
  double get finalPrice => _finalPrice;

  double get totalPrice => calculateTotalPrice();

  // ✅ Getter للحصول على نسبة العمولة الديناميكية
  double get platformCommissionRate {
    // يجب أن تكون القيمة كسرًا عشريًا (مثال: 0.15)
    return _settingsProvider?.platformCommissionRate ?? 0.0;
  }

  double calculateTotalPrice() =>
      _cartItems.fold(0.0, (sum, item) => sum + item.price);

  void addItem(Service service) {
    if (!_cartItems.any((item) => item.id == service.id)) {
      _cartItems.add(service);
      _recalculateFinalPrice();
      notifyListeners();
    }
  }

  void removeItem(Service service) {
    _cartItems.removeWhere((item) => item.id == service.id);
    _recalculateFinalPrice();
    notifyListeners();
  }

  void removeFromCart(Service service) => removeItem(service);

  bool isServiceSelected(Service service) =>
      _cartItems.any((item) => item.id == service.id);

  void toggleServiceSelection(Service service) {
    if (isServiceSelected(service)) {
      removeItem(service);
    } else {
      addItem(service);
    }
  }

  void clearCart() {
    _cartItems.clear();
    _selectedAppointmentDate = null;
    _notes = '';
    _orderErrorMessage = null;
    _serviceProviderType = 'غير محدد';
    _selectedLat = null;
    _selectedLng = null;
    _appliedCouponCode = null;
    _currentDiscountAmount = 0.0;
    _finalPrice = 0.0;
    notifyListeners();
  }

  void setAppointmentDate(DateTime? dateTime) {
    _selectedAppointmentDate = dateTime;
    notifyListeners();
  }

  void setNotes(String notes) {
    _notes = notes;
    notifyListeners();
  }
  
  // ✅ دالة updateDependencies لقبول جميع التبعيات (لـ ProxyProvider2)
  void updateDependencies(AuthProvider newAuth, SettingsProvider? settingsProvider) {
    _authProvider = newAuth;
    _settingsProvider = settingsProvider;
  }
  
  void updateAuth(AuthProvider newAuth) {
    _authProvider = newAuth;
  }


  void setServiceProviderType(String type) {
    _serviceProviderType = type;
    notifyListeners();
  }

  void setSelectedLocation(double lat, double lng) {
    _selectedLat = lat;
    _selectedLng = lng;
    notifyListeners();
  }

  // -------------------------------
  // 🎟️ إدارة الخصومات
  // -------------------------------

  Future<void> applyCouponCode(String code, double originalPrice) async {
    try {
      final result = await _discountService.applyCoupon(code, originalPrice);
      _currentDiscountAmount = result['discountAmount']!;
      _finalPrice = result['finalPrice']!;
      _appliedCouponCode = code.toUpperCase(); 
      notifyListeners();
    } catch (e) {
      _currentDiscountAmount = 0.0;
      _finalPrice = calculateTotalPrice();
      _appliedCouponCode = null;
      notifyListeners();
      throw Exception("الكوبون غير صالح أو منتهي الصلاحية.");
    }
  }
  
  // ✅✨ الدالة المضافة التي تحل خطأ 'removeCoupon'
  void removeCoupon() {
    _appliedCouponCode = null;
    _currentDiscountAmount = 0.0;
    _finalPrice = calculateTotalPrice(); // إعادة السعر إلى الإجمالي
    notifyListeners();
  }

  void _recalculateFinalPrice() {
    final originalPrice = calculateTotalPrice();

    // يتم إلغاء الخصم تلقائياً عند تغيير الخدمات (لأنه قد لا يفي بالحد الأدنى)
    _appliedCouponCode = null;
    _currentDiscountAmount = 0.0;
    _finalPrice = originalPrice;
  }

  // -------------------------------
  // 🚀 إرسال الطلب
  // -------------------------------
  Future<String?> placeOrder(
      String phoneNumber, 
      String deliveryAddress, 
      BuildContext context,
      {
        required String paymentMethod, 
        bool requiresAppointment = true,
      }) async {
    if (_cartItems.isEmpty || _authProvider.currentUser == null) {
      showSnackBar(context, 'خطأ! تأكد من وجود خدمات في السلة وأنك مسجل دخول.', isError: true);
      return null;
    }
    if (_selectedLat == null || _selectedLng == null) {
      showSnackBar(context, 'الرجاء تحديد الموقع على الخريطة.', isError: true);
      return null;
    }


    _isPlacingOrder = true;
    _orderErrorMessage = null;
    notifyListeners();

    try {
      final userId = _authProvider.currentUser!.uid; 
      final patientName =
          _authProvider.currentUserProfile?.name ?? 'مستخدم غير معروف';
      
      final originalPrice = calculateTotalPrice();
      final discount = _currentDiscountAmount;
      final finalPriceToCharge = finalPrice > 0 ? finalPrice : originalPrice;
      final finalCommissionRate = platformCommissionRate; 
      final couponCode = _appliedCouponCode;

      final order = Order(
        id: '',
        userId: userId,
        patientName: patientName,
        services: List.from(_cartItems),
        
        // ✅ حقول المحاسبة الجديدة
        totalPrice: originalPrice, 
        finalPrice: finalPriceToCharge, 
        discountAmount: discount, 
        couponCode: couponCode, 
        paymentMethod: paymentMethod, 
        platformCommissionRate: finalCommissionRate, 

        // حقول أخرى ضرورية
        status: 'pending',
        orderDate: DateTime.now(),
        deliveryAddress: deliveryAddress,
        phoneNumber: phoneNumber,
        serviceProviderType: _serviceProviderType,
        isRated: false,
        appointmentDate: _selectedAppointmentDate,
        notes: _notes,
        locationLat: _selectedLat,
        locationLng: _selectedLng,
      );

      final docRef = await _firestoreService.addOrder(order);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activeOrderId', docRef.id);

      clearCart();
      showSnackBar(context, 'تم إرسال طلبك بنجاح!');
      return docRef.id;
    } catch (e) {
      print("!!!!!!!! ERROR PLACING ORDER: $e !!!!!!!!");
      _orderErrorMessage = 'حدث خطأ أثناء إرسال الطلب.';
      showSnackBar(context, _orderErrorMessage!, isError: true);
      return null;
    } finally {
      _isPlacingOrder = false;
      notifyListeners();
    }
  }
}
// lib/screens/cart_screen.dart

import 'package:cure_app/providers/cart_provider.dart';
import 'package:cure_app/providers/active_order_provider.dart';
import 'package:cure_app/screens/location_picker_screen.dart';
import 'package:cure_app/screens/order_tracking_screen.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:cure_app/utils/helpers.dart';
import 'package:cure_app/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();

  String? _couponError; 
  // ✅ حالة طريقة الدفع الجديدة (الافتراض هو نقدي)
  String _selectedPaymentMethod = paymentMethodCash; 

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _couponController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _navigateToTracking(String? orderId) {
    if (orderId != null && mounted) {
      return Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    }
    return Future.value();
  }

  // ✅ منطق تطبيق الكوبون
  void _applyCoupon(CartProvider cartProvider) async {
    final couponCode = _couponController.text.trim();
    final double originalPrice = cartProvider.totalPrice;

    if (couponCode.isEmpty) {
      setState(() => _couponError = 'الرجاء إدخال رمز الكوبون.');
      return;
    }
    
    // إلغاء أي كوبون مطبق مسبقاً قبل محاولة تطبيق الجديد
    if (cartProvider.appliedCouponCode != null) {
      cartProvider.removeCoupon();
    }
    
    setState(() => _couponError = null);

    try {
      await cartProvider.applyCouponCode(couponCode, originalPrice);
      if (mounted) {
        setState(() => _couponError = 'تم تطبيق الخصم بنجاح! 🎉');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _couponError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // ✅ دالة الطلب الآن (تستخدم الطريقة المختارة)
  void _orderNow(CartProvider cartProvider) {
    if (_formKey.currentState!.validate()) {
      if (_selectedPaymentMethod == paymentMethodOnline) {
        showSnackBar(context, 'سيتم توفير الدفع الإلكتروني قريباً! 🚧', isError: true);
        return;
      }
      
      cartProvider.setAppointmentDate(null);
      cartProvider
          .placeOrder(
        _phoneController.text.trim(),
        _addressController.text.trim(),
        context,
        requiresAppointment: false,
        paymentMethod: _selectedPaymentMethod, // ✅ تمرير الحقل المطلوب
      )
          .then((orderId) async {
        if (orderId != null) {
          await context.read<ActiveOrderProvider>().refreshActiveOrder();
          _navigateToTracking(orderId);
        }
      });
    }
  }

  // ✅ دالة طلب بموعد (تستخدم الطريقة المختارة)
  Future<void> _orderWithAppointment(CartProvider cartProvider) async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedPaymentMethod == paymentMethodOnline) {
      showSnackBar(context, 'سيتم توفير الدفع الإلكتروني قريباً! 🚧', isError: true);
      return;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: kPrimaryColor,
                  surface: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: kPrimaryColor,
                  surface: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && mounted) {
      final fullDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      cartProvider.setAppointmentDate(fullDateTime);

      final newOrderId = await cartProvider.placeOrder(
        _phoneController.text.trim(),
        _addressController.text.trim(),
        context,
        requiresAppointment: true,
        paymentMethod: _selectedPaymentMethod, // ✅ تمرير الحقل المطلوب
      );

      if (newOrderId != null) {
        await context.read<ActiveOrderProvider>().refreshActiveOrder();
        _navigateToTracking(newOrderId);
      }
    }
  }
  
  // ✅ دالة بناء خيار الدفع (Radio Button Style)
  Widget _buildPaymentOption({
    required String label,
    required String value,
    required IconData icon,
    bool isComingSoon = false,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    final isDisabled = isComingSoon;
    
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled && !isSelected
          ? () => showSnackBar(context, 'الدفع الإلكتروني تحت الإعداد.', isError: true) 
          : () {
              setState(() {
                _selectedPaymentMethod = value;
              });
            },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? kPrimaryColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isDisabled && !isSelected ? Colors.grey : kPrimaryColor,
                size: 30,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDisabled && !isSelected ? Colors.grey : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isComingSoon) 
                Text(
                  '(قريباً)',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ دالة بناء سلة الخدمات
  Widget _buildServicesList(CartProvider cartProvider) {
    return ListView.builder(
      itemCount: cartProvider.cartItems.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final service = cartProvider.cartItems[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(service.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${service.price.toStringAsFixed(2)} جنيه', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
            trailing: Container(
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () => cartProvider.removeItem(service),
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ دالة بناء حقل نصي عصري
  Widget _buildModernTextField({
    TextEditingController? controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: kPrimaryColor)),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: kPrimaryColor, width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red, width: 2)),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }

  // ✅ دالة زر الموقع
  Widget _buildLocationButton(CartProvider cartProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () async {
          final selectedLocation = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (context) => const LocationPickerScreen()));
          if (selectedLocation != null) {
            cartProvider.setSelectedLocation(selectedLocation.latitude, selectedLocation.longitude);
            _addressController.text = 'الموقع: ${selectedLocation.latitude.toStringAsFixed(5)}, ${selectedLocation.longitude.toStringAsFixed(5)}';
          }
        },
        icon: const Icon(Icons.map_outlined, color: Colors.white),
        label: const Text('اختر الموقع من الخريطة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      ),
    );
  }

  // ✅ دالة اختيار نوع مقدم الخدمة
  Widget _buildProviderTypeSelector(CartProvider cartProvider) {
    final types = ['ممرض', 'ممرضة', 'غير محدد'];
    return Row(
      children: types.map((type) {
        final isSelected = cartProvider.serviceProviderType == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: isSelected ? LinearGradient(colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)]) : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected ? [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: ElevatedButton(
                onPressed: () => cartProvider.setServiceProviderType(type),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: isSelected ? Colors.white : Colors.black87, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(type, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ✅ دالة بناء شريط التطبيق المخصص
  Widget _buildCustomAppBar(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.3))),
            child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
        ],
      ),
    );
  }

  // ✅ دالة بناء البطاقة الزجاجية
  Widget _buildGlassCard({
    required Widget child,
    required String title,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: kPrimaryColor), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ✅ دالة مساعدة لعرض صفوف السعر
  Widget _buildPriceRow(String label, double amount, Color color,
      {bool isFinal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isFinal ? 18 : 16, fontWeight: isFinal ? FontWeight.bold : FontWeight.normal, color: color)),
          Text('${amount.toStringAsFixed(2)} جنيه', style: TextStyle(fontSize: isFinal ? 18 : 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ✅ دالة بناء زر الإجراءات
  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
    required Color color,
    Color textColor = Colors.white,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }

  // ✅ دالة بناء بطاقة الكوبون الجديدة
  Widget _buildCouponCard(CartProvider cartProvider) {
    final bool isCouponApplied = cartProvider.appliedCouponCode != null;

    return _buildGlassCard(
      title: 'كود الخصم',
      icon: Icons.local_offer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('هل لديك كوبون خصم؟', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: TextFormField(
                    controller: _couponController,
                    decoration: InputDecoration(hintText: 'أدخل رمز الكوبون', isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: kPrimaryColor, width: 2))),
                    onChanged: (_) {
                       if (isCouponApplied) cartProvider.removeCoupon();
                       setState(() => _couponError = null);
                    }
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: cartProvider.isPlacingOrder
                    ? null
                    : () => isCouponApplied ? cartProvider.removeCoupon() : _applyCoupon(cartProvider),
                style: ElevatedButton.styleFrom(backgroundColor: isCouponApplied ? Colors.red : kPrimaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text(isCouponApplied ? 'إلغاء' : 'تطبيق', style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
          if (_couponError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(_couponError!, style: TextStyle(color: _couponError!.contains('نجاح') ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ✅ دالة بناء ملخص الأسعار النهائية
  Widget _buildPricingCard(CartProvider cartProvider) {
    final double originalPrice = cartProvider.totalPrice;
    final double currentDiscount = cartProvider.currentDiscountAmount;
    final double finalPrice = cartProvider.finalPrice;
    final String? appliedCode = cartProvider.appliedCouponCode;

    return Column(
      children: [
        _buildCouponCard(cartProvider), 
        const SizedBox(height: 20),
        
        // ✅ القسم الجديد: اختيار طريقة الدفع
        _buildGlassCard(
          title: 'اختر طريقة الدفع',
          icon: Icons.payment,
          child: Row(
            children: [
              _buildPaymentOption(
                label: 'الدفع النقدي',
                value: paymentMethodCash,
                icon: Icons.money_rounded,
              ),
              const SizedBox(width: 10),
              _buildPaymentOption(
                label: 'فيزا/بطاقة',
                value: paymentMethodOnline,
                icon: Icons.credit_card_rounded,
                isComingSoon: true,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),

        // ملخص الدفع النهائي
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildPriceRow('الإجمالي قبل الخصم:', originalPrice, Colors.white.withOpacity(0.8)),
                if (currentDiscount > 0)
                  _buildPriceRow('الخصم المطبق (${appliedCode ?? 'لا يوجد'}):', -currentDiscount, kAccentColor),
                if (currentDiscount > 0)
                  const Divider(height: 24, thickness: 1.5, color: Colors.white70),
                _buildPriceRow('المبلغ المطلوب دفعه:', finalPrice, Colors.white, isFinal: true),
                const SizedBox(height: 24),
                
                // زر الإجراءات
                Row(
                  children: [
                    Expanded(child: _buildActionButton(text: 'تأكيد الطلب', onPressed: cartProvider.isPlacingOrder ? null : () => _orderNow(cartProvider), color: Colors.green)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildActionButton(text: 'حدد موعد', onPressed: cartProvider.isPlacingOrder ? null : () => _orderWithAppointment(cartProvider), color: Colors.white, textColor: kPrimaryColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✅ دالة بناء واجهة الشاشة الرئيسية
  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        // ... (منطق عرض الشاشة فارغة)
        if (cartProvider.cartItems.isEmpty) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kPrimaryColor, Colors.white], stops: [0.0, 0.3])),
              child: SafeArea(child: Column(children: [_buildCustomAppBar(context, 'عربة الخدمات'), const Expanded(child: EmptyState(message: 'عربة الخدمات فارغة. ابدأ بإضافة بعض الخدمات!', icon: Icons.shopping_cart_outlined))])),
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [kPrimaryColor, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.0, 0.3])),
            child: SafeArea(
              child: Column(
                children: [
                  _buildCustomAppBar(context, 'مراجعة الطلب'),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGlassCard(child: _buildServicesList(cartProvider), title: 'الخدمات المطلوبة', icon: Icons.medical_services_outlined),
                                const SizedBox(height: 20),
                                _buildGlassCard(title: 'بيانات التواصل', icon: Icons.contact_phone_outlined, child: Column(children: [
                                  _buildModernTextField(controller: _phoneController, label: 'رقم هاتف للتواصل', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, validator: (value) => (value == null || value.isEmpty) ? 'رقم الهاتف مطلوب' : null),
                                  const SizedBox(height: 20),
                                  _buildModernTextField(controller: _addressController, label: 'العنوان بالتفصيل', icon: Icons.location_on_outlined, maxLines: 2, validator: (value) => (value == null || value.isEmpty) ? 'العنوان مطلوب' : null),
                                  const SizedBox(height: 16),
                                  _buildLocationButton(cartProvider),
                                ])),
                                const SizedBox(height: 20),
                                _buildGlassCard(title: 'نوع مقدم الخدمة', icon: Icons.person_outline, child: _buildProviderTypeSelector(cartProvider)),
                                const SizedBox(height: 20),
                                _buildGlassCard(title: 'ملاحظات إضافية', icon: Icons.notes_outlined, child: _buildModernTextField(onChanged: (value) => cartProvider.setNotes(value), label: 'هل تحتاج أن نشتري لك أي أدوات؟ (اختياري)', icon: Icons.edit_note_outlined, maxLines: 3)),
                                const SizedBox(height: 20),
                                _buildPricingCard(cartProvider), 
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
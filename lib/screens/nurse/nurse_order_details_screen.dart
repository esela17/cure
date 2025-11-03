// lib/screens/nurse/nurse_order_details_screen.dart

import 'package:cure_app/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cure_app/models/order.dart';
import 'package:cure_app/models/transaction_model.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/providers/nurse_provider.dart';
import 'package:cure_app/services/communication_service.dart';
import 'package:cure_app/services/firestore_service.dart';
import 'package:cure_app/utils/helpers.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:cure_app/widgets/loading_indicator.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📋 حصر شامل لجميع الحالات (All Possible Cases)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 1️⃣ حالات Order Status:
///    ├─ pending: في انتظار الموافقة
///    ├─ accepted: تم قبول الطلب
///    ├─ arrived: وصل الممرض
///    ├─ completed: تم إنهاء الخدمة
///    ├─ rejected: تم رفض الطلب
///    └─ cancelled: تم إلغاء الطلب
///
/// 2️⃣ حالات Payment Method:
///    ├─ cash: دفع نقدي
///    └─ online: دفع إلكتروني
///
/// 3️⃣ حالات Service Provider Type:
///    ├─ nurseMale: ممرض (ذكر)
///    ├─ nurseFemale: ممرضة (أنثى)
///    └─ null: غير محدد
///
/// 4️⃣ حالات الأزرار (Status × Payment Method):
///    ├─ pending + any payment → [قبول] [رفض]
///    ├─ accepted + any payment → [تأكيد الوصول]
///    ├─ arrived + cash → [تأكيد استلام الدفع النقدي]
///    ├─ arrived + online → [إنهاء الخدمة]
///    └─ completed/rejected/cancelled → عرض الحالة فقط
///
/// 5️⃣ حالات البيانات الاختيارية:
///    ├─ appointmentDate: موجود ✅ / غير موجود ❌
///    ├─ serviceProviderType: موجود ✅ / غير موجود ❌
///    ├─ notes: موجود وليس فارغ ✅ / فارغ أو null ❌
///    ├─ rejectReason: موجود وليس فارغ ✅ / فارغ أو null ❌
///    ├─ discountAmount: أكبر من 0 ✅ / يساوي 0 ❌
///    └─ locationLat/Lng: موجود ✅ / غير موجود ❌
///
/// 6️⃣ حالات Stream:
///    ├─ ConnectionState.waiting → Loading
///    ├─ hasError → Error Screen
///    ├─ !hasData → No Data Screen
///    └─ hasData → Display Order
///
/// 7️⃣ حالات العمليات (Operations):
///    ├─ Processing → عرض Loading
///    ├─ Success → عرض رسالة نجاح
///    └─ Error → عرض رسالة خطأ
///
/// ═══════════════════════════════════════════════════════════════════════════

class NurseOrderDetailsScreen extends StatefulWidget {
  final Order initialOrder;

  const NurseOrderDetailsScreen({super.key, required this.initialOrder});

  @override
  State<NurseOrderDetailsScreen> createState() =>
      _NurseOrderDetailsScreenState();
}

class _NurseOrderDetailsScreenState extends State<NurseOrderDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isProcessingCash = false;
  bool _isProcessingAction = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // 📌 Constants: جميع حالات الطلب الممكنة
  // ═══════════════════════════════════════════════════════════════════════════
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusArrived = 'arrived';
  static const String statusCompleted = 'completed';
  static const String statusRejected = 'rejected';
  static const String statusCancelled = 'cancelled';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 💰 SECTION: Cash Payment Handling (معالجة الدفع النقدي)
  // ═══════════════════════════════════════════════════════════════════════════

  /// ✅ تأكيد استلام الدفع النقدي مع عرض تفاصيل العمولة
  ///
  /// Cases:
  /// - User confirms → Process payment → Success/Failure
  /// - User cancels → Do nothing
  Future<void> _confirmCashCompletion(BuildContext context, Order order) async {
    final firestoreService = context.read<FirestoreService>();
    final commission =
        _calculateCommission(order.finalPrice, order.platformCommissionRate);
    final nurseEarnings = order.finalPrice - commission;

    // Case 1: عرض dialog التأكيد
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.handshake_outlined, color: kPrimaryColor),
            const SizedBox(width: 8),
            const Text('تأكيد استلام الدفع النقدي'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تأكد من استلام المبلغ كاملاً قبل التأكيد',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildPaymentDetailRow('المبلغ المستحق:',
                  '${order.finalPrice.toStringAsFixed(2)} ج.م',
                  isBold: true),
              const Divider(height: 20),
              _buildPaymentDetailRow(
                  'عمولة المنصة (${order.platformCommissionRate}%):',
                  '${commission.toStringAsFixed(2)} ج.م',
                  color: Colors.red.shade700),
              _buildPaymentDetailRow(
                  'صافي ربحك:', '${nurseEarnings.toStringAsFixed(2)} ج.م',
                  color: kPrimaryColor, isBold: true),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '💡 سيتم إضافة صافي المبلغ إلى رصيدك فوراً',
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.check_circle),
            label: const Text('تأكيد الاستلام'),
          ),
        ],
      ),
    );

    // Case 2: User cancelled - لا تفعل شيء
    if (confirm != true) return;

    // Case 3: Processing payment
    setState(() => _isProcessingCash = true);
    try {
      await firestoreService.completeOrder(order.id);

      // Case 4: Success
      if (mounted) {
        showSnackBar(context,
            '✅ تم تسجيل الدفع وإضافة ${nurseEarnings.toStringAsFixed(2)} ج.م لرصيدك');
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Case 5: Failure
      if (mounted) {
        showSnackBar(context, 'فشل تسجيل الدفع: ${e.toString()} ❌',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessingCash = false);
    }
  }

  /// دالة مساعدة لعرض تفاصيل الدفع في الـ Dialog
  Widget _buildPaymentDetailRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color ?? Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🧮 SECTION: Calculations & Utilities
  // ═══════════════════════════════════════════════════════════════════════════

  /// حساب العمولة
  double _calculateCommission(double finalPrice, double commissionRate) {
    return finalPrice * (commissionRate / 100);
  }

  /// الحصول على لون حسب طريقة الدفع
  /// Cases: cash → orange, online → primary color
  Color _getPaymentMethodColor(String paymentMethod) {
    return paymentMethod == paymentMethodCash ? Colors.orange : kPrimaryColor;
  }

  /// الحصول على أيقونة حسب طريقة الدفع
  /// Cases: cash → money icon, online → credit card icon
  IconData _getPaymentMethodIcon(String paymentMethod) {
    return paymentMethod == paymentMethodCash ? Icons.money : Icons.credit_card;
  }

  /// تحويل نوع مقدم الخدمة إلى نص عربي
  /// Cases: nurseMale, nurseFemale, null, other
  String _getServiceProviderTypeText(String? type) {
    if (type == null) return 'غير محدد';

    switch (type) {
      case 'nurseMale':
        return 'ممرض';
      case 'nurseFemale':
        return 'ممرضة';
      default:
        return 'غير محدد';
    }
  }

  /// الحصول على نص طريقة الدفع بالعربية
  String _getPaymentMethodText(String paymentMethod) {
    return paymentMethod == paymentMethodCash ? 'نقدي 💵' : 'إلكتروني 💳';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏗️ SECTION: Main Build Method
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'تفاصيل الطلب',
          style: TextStyle(
              color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<Order>(
        stream: firestoreService.getOrderStream(widget.initialOrder.id),
        builder: (context, snapshot) {
          // ═════════════════════════════════════════════════════════════════
          // 📡 Stream State Cases (حالات الـ Stream)
          // ═════════════════════════════════════════════════════════════════

          // Case 1: Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }

          // Case 2: Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'خطأ في تحميل البيانات',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          // Case 3: No data
          if (!snapshot.hasData) {
            return const Center(
              child: Text('الطلب غير موجود', style: TextStyle(fontSize: 16)),
            );
          }

          // Case 4: Data loaded successfully
          final order = snapshot.data!;

          // تحديد ما إذا كان يجب عرض بانر الدفع النقدي
          final bool showCashPaymentBanner = order.status == statusArrived &&
              order.paymentMethod == paymentMethodCash;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // بانر تنبيه الدفع النقدي (فقط في حالة arrived + cash)
                if (showCashPaymentBanner)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.1),
                          Colors.orange.withOpacity(0.05)
                        ],
                      ),
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.orange.shade300, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payments,
                            color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'بانتظار تأكيد استلام الدفع النقدي',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildCompactOrderCard(context, order),
                        const SizedBox(height: 16),
                        _buildFinancialInfoCard(order),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 SECTION: Order Card Components
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCompactOrderCard(BuildContext context, Order order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildOrderHeader(order),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // بيانات المريض
                _buildCompactSection(
                  title: 'بيانات المريض',
                  icon: Icons.person,
                  color: const Color(0xFF2196F3),
                  children: [
                    _buildCompactRow('اسم المريض', order.patientName),
                    _buildCompactRow(
                      'الهاتف',
                      order.phoneNumber,
                      action: _buildCircleIconButton(
                        icon: Icons.phone,
                        color: const Color(0xFF4CAF50),
                        onTap: () async {
                          try {
                            await CommunicationService.makePhoneCall(
                                order.phoneNumber);
                          } catch (_) {
                            if (mounted) {
                              showSnackBar(context, 'لا يمكن إجراء المكالمة',
                                  isError: true);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // الموقع
                _buildCompactSection(
                  title: 'الموقع',
                  icon: Icons.location_on,
                  color: const Color(0xFFFF5722),
                  children: [
                    _buildCompactRow(
                      'العنوان',
                      order.deliveryAddress,
                      isAddress: true,
                      action: _buildCircleIconButton(
                        icon: Icons.map,
                        color: kPrimaryColor,
                        onTap: () async {
                          try {
                            if (order.locationLat != null &&
                                order.locationLng != null) {
                              await CommunicationService
                                  .launchMapFromCoordinates(
                                      order.locationLat!, order.locationLng!);
                            } else {
                              await CommunicationService.launchMapFromAddress(
                                  order.deliveryAddress);
                            }
                          } catch (_) {
                            if (mounted) {
                              showSnackBar(context, 'فشل في فتح الخرائط',
                                  isError: true);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // الخدمات
                _buildCompactSection(
                  title: 'الخدمات',
                  icon: Icons.medical_services,
                  color: const Color(0xFF9C27B0),
                  children: [
                    ...order.services
                        .map((service) => _buildServiceRow(service))
                  ],
                ),
                const SizedBox(height: 12),

                // التفاصيل
                _buildCompactSection(
                  title: 'التفاصيل',
                  icon: Icons.info,
                  color: const Color(0xFFFF9800),
                  children: [
                    _buildCompactRow(
                        'تاريخ الطلب', formatDateTime(order.orderDate)),

                    // Case: يوجد موعد محدد
                    if (order.appointmentDate != null)
                      _buildCompactRow('موعد الخدمة',
                          formatDateTime(order.appointmentDate!)),

                    // Case: يوجد تفضيل نوع الممرض
                    if (order.serviceProviderType != null)
                      _buildCompactRow(
                          'التفضيل',
                          _getServiceProviderTypeText(
                              order.serviceProviderType)),

                    // Case: يوجد ملاحظات
                    if (order.notes != null && order.notes!.isNotEmpty)
                      _buildCompactRow('ملاحظات', order.notes!, isNote: true),

                    // Case: يوجد سبب رفض
                    if (order.rejectReason != null &&
                        order.rejectReason!.isNotEmpty)
                      _buildCompactRow('سبب الرفض', order.rejectReason!,
                          isNote: true),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTotalSection(order),
                const SizedBox(height: 16),

                // ═════════════════════════════════════════════════════════════
                // 🎛️ الأزرار حسب حالة الطلب وطريقة الدفع
                // ═════════════════════════════════════════════════════════════
                if (order.status == statusArrived &&
                    order.paymentMethod == paymentMethodCash)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingCash
                          ? null
                          : () => _confirmCashCompletion(context, order),
                      icon: _isProcessingCash
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.handshake_outlined),
                      label: Text(
                        _isProcessingCash
                            ? 'جاري المعالجة...'
                            : 'تأكيد استلام ${order.finalPrice.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isProcessingCash ? 0 : 2,
                      ),
                    ),
                  )
                else
                  _buildActionButtons(context, order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 💳 SECTION: Financial Info Card
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFinancialInfoCard(Order order) {
    final commission =
        _calculateCommission(order.finalPrice, order.platformCommissionRate);
    final nurseEarnings = order.finalPrice - commission;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getPaymentMethodIcon(order.paymentMethod),
                color: _getPaymentMethodColor(order.paymentMethod),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'معلومات مالية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getPaymentMethodColor(order.paymentMethod),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFinancialRow(
              'طريقة الدفع', _getPaymentMethodText(order.paymentMethod)),
          _buildFinancialRow(
              'السعر الإجمالي', '${order.totalPrice.toStringAsFixed(2)} ج.م'),

          // Case: يوجد خصم
          if (order.discountAmount > 0)
            _buildFinancialRow(
                'الخصم', '-${order.discountAmount.toStringAsFixed(2)} ج.م'),

          _buildFinancialRow(
              'السعر النهائي', '${order.finalPrice.toStringAsFixed(2)} ج.م',
              isBold: true),
          const Divider(height: 20),
          _buildFinancialRow(
              'نسبة العمولة', '${order.platformCommissionRate}%'),
          _buildFinancialRow(
              'قيمة العمولة', '-${commission.toStringAsFixed(2)} ج.م',
              color: Colors.red.shade700),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: kPrimaryColor, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'صافي ربحك',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${nurseEarnings.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontSize: 16,
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color ?? Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 SECTION: UI Helper Components
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildOrderHeader(Order order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _getStatusGradient(order.status)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getStatusIcon(order.status),
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(order.status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'رقم الطلب: ${order.id.substring(0, 8)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRow(
    String label,
    String value, {
    Widget? action,
    bool isAddress = false,
    bool isNote = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': ',
              style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w600,
              ),
              maxLines: isAddress || isNote ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }

  Widget _buildServiceRow(service) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF9C27B0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              service.name,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${service.price.toStringAsFixed(0)} ج.م',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(Order order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          const Text(
            'إجمالي المبلغ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${order.totalPrice.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎛️ SECTION: Action Buttons (الأزرار حسب الحالة)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildActionButtons(BuildContext context, Order order) {
    final nurseProvider = Provider.of<NurseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Case: جاري معالجة عملية
    if (_isProcessingAction) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // تحديد الأزرار حسب الحالة
    switch (order.status) {
      // ═══════════════════════════════════════════════════════════════════════
      // Case 1: Pending - في انتظار الموافقة
      // ═══════════════════════════════════════════════════════════════════════
      case statusPending:
        return Row(
          children: [
            Expanded(
              child: _buildCompactButton(
                label: 'قبول الطلب',
                icon: Icons.check,
                color: kPrimaryColor,
                onPressed: () async {
                  setState(() => _isProcessingAction = true);
                  try {
                    final success = await nurseProvider.acceptOrder(
                        order, authProvider.currentUserProfile!);

                    if (success && mounted) {
                      showSnackBar(context, '✅ تم قبول الطلب بنجاح');
                    } else if (mounted) {
                      showSnackBar(
                          context, nurseProvider.errorMessage ?? 'حدث خطأ',
                          isError: true);
                    }
                  } catch (e) {
                    if (mounted) {
                      showSnackBar(context, 'حدث خطأ: ${e.toString()}',
                          isError: true);
                    }
                  } finally {
                    if (mounted) setState(() => _isProcessingAction = false);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompactButton(
                label: 'رفض الطلب',
                icon: Icons.close,
                color: const Color(0xFFf44336),
                onPressed: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (ctx) => _buildRejectReasonDialog(ctx),
                  );

                  if (result != null && result.isNotEmpty) {
                    setState(() => _isProcessingAction = true);
                    try {
                      final success = await nurseProvider.rejectOrder(order);
                      if (success && mounted) {
                        showSnackBar(context, 'تم رفض الطلب');
                        Navigator.of(context).pop();
                      } else if (mounted) {
                        showSnackBar(
                            context, nurseProvider.errorMessage ?? 'حدث خطأ',
                            isError: true);
                      }
                    } catch (e) {
                      if (mounted) {
                        showSnackBar(context, 'حدث خطأ: ${e.toString()}',
                            isError: true);
                      }
                    } finally {
                      if (mounted) setState(() => _isProcessingAction = false);
                    }
                  }
                },
              ),
            ),
          ],
        );

      // ═══════════════════════════════════════════════════════════════════════
      // Case 2: Accepted - تم القبول
      // ═══════════════════════════════════════════════════════════════════════
      case statusAccepted:
        return _buildCompactButton(
          label: 'تأكيد الوصول',
          icon: Icons.location_on,
          color: kAccentColor,
          onPressed: () async {
            setState(() => _isProcessingAction = true);
            try {
              final success = await nurseProvider.markAsArrived(order);
              if (success && mounted) {
                showSnackBar(context, '✅ تم تأكيد الوصول بنجاح');
              } else if (mounted) {
                showSnackBar(context, nurseProvider.errorMessage ?? 'حدث خطأ',
                    isError: true);
              }
            } catch (e) {
              if (mounted) {
                showSnackBar(context, 'حدث خطأ: ${e.toString()}',
                    isError: true);
              }
            } finally {
              if (mounted) setState(() => _isProcessingAction = false);
            }
          },
          fullWidth: true,
        );

      // ═══════════════════════════════════════════════════════════════════════
      // Case 3: Arrived - وصل الممرض
      // Sub-cases: cash payment (handled above) / online payment
      // ═══════════════════════════════════════════════════════════════════════
      case statusArrived:
        // Sub-case: Online payment (الدفع الإلكتروني)
        if (order.paymentMethod != paymentMethodCash) {
          return _buildCompactButton(
            label: 'إنهاء الخدمة',
            icon: Icons.check_circle,
            color: kPrimaryColor,
            onPressed: () async {
              setState(() => _isProcessingAction = true);
              try {
                final success = await nurseProvider.completeOrder(order);
                if (success && mounted) {
                  showSnackBar(context, '✅ تم إنهاء الخدمة بنجاح');
                  Navigator.of(context).pop();
                } else if (mounted) {
                  showSnackBar(context, nurseProvider.errorMessage ?? 'حدث خطأ',
                      isError: true);
                }
              } catch (e) {
                if (mounted) {
                  showSnackBar(context, 'حدث خطأ: ${e.toString()}',
                      isError: true);
                }
              } finally {
                if (mounted) setState(() => _isProcessingAction = false);
              }
            },
            fullWidth: true,
          );
        }
        // Sub-case: Cash payment (يتم معالجته في الأعلى)
        return const SizedBox.shrink();

      // ═══════════════════════════════════════════════════════════════════════
      // Case 4: Completed - تم الإنجاز
      // ═══════════════════════════════════════════════════════════════════════
      case statusCompleted:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.task_alt, color: const Color(0xFF9C27B0), size: 20),
              const SizedBox(width: 8),
              const Text(
                'تم إنهاء الخدمة بنجاح ✅',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9C27B0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      // ═══════════════════════════════════════════════════════════════════════
      // Case 5: Rejected - تم الرفض
      // ═══════════════════════════════════════════════════════════════════════
      case statusRejected:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'تم رفض الطلب',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (order.rejectReason != null &&
                  order.rejectReason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'السبب: ${order.rejectReason}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ],
          ),
        );

      // ═══════════════════════════════════════════════════════════════════════
      // Case 6: Cancelled - تم الإلغاء
      // ═══════════════════════════════════════════════════════════════════════
      case statusCancelled:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'تم إلغاء الطلب',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      // ═══════════════════════════════════════════════════════════════════════
      // Case 7: Unknown/Default - حالة غير معروفة
      // ═══════════════════════════════════════════════════════════════════════
      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.help_outline, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'حالة غير معروفة: ${order.status}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildRejectReasonDialog(BuildContext context) {
    String rejectReason = '';

    return AlertDialog(
      title: const Text('سبب رفض الطلب'),
      content: TextField(
        onChanged: (value) => rejectReason = value,
        decoration: const InputDecoration(
          hintText: 'أدخل سبب رفض الطلب...',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, rejectReason),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('رفض الطلب'),
        ),
      ],
    );
  }

  Widget _buildCompactButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 SECTION: Status Styling Helpers (تنسيق الألوان والأيقونات)
  // ═══════════════════════════════════════════════════════════════════════════

  /// تحديد تدرج اللون حسب الحالة
  /// All Status Cases: pending, accepted, arrived, completed, rejected, cancelled, unknown
  List<Color> _getStatusGradient(String status) {
    switch (status) {
      case statusPending:
        return [const Color(0xFFFF9800), const Color(0xFFF57C00)];
      case statusAccepted:
        return [kPrimaryColor, kPrimaryColor.withOpacity(0.8)];
      case statusArrived:
        return [kAccentColor, kAccentColor.withOpacity(0.8)];
      case statusCompleted:
        return [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)];
      case statusRejected:
        return [const Color(0xFFf44336), const Color(0xFFd32f2f)];
      case statusCancelled:
        return [const Color(0xFF9E9E9E), const Color(0xFF757575)];
      default:
        return [const Color(0xFF9E9E9E), const Color(0xFF757575)];
    }
  }

  /// تحديد الأيقونة حسب الحالة
  IconData _getStatusIcon(String status) {
    switch (status) {
      case statusPending:
        return Icons.pending_actions;
      case statusAccepted:
        return Icons.check_circle;
      case statusArrived:
        return Icons.location_on;
      case statusCompleted:
        return Icons.task_alt;
      case statusRejected:
        return Icons.cancel;
      case statusCancelled:
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  /// تحديد النص العربي حسب الحالة
  String _getStatusText(String status) {
    switch (status) {
      case statusPending:
        return 'في انتظار الموافقة';
      case statusAccepted:
        return 'تم قبول الطلب';
      case statusArrived:
        return 'وصل المُمرض';
      case statusCompleted:
        return 'تم إنهاء الخدمة';
      case statusRejected:
        return 'تم رفض الطلب';
      case statusCancelled:
        return 'تم إلغاء الطلب';
      default:
        return 'حالة غير محددة';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ✅ END OF FILE - الكود جاهز للاستخدام
// ═══════════════════════════════════════════════════════════════════════════

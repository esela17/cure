import 'package:cure_app/screens/leave_review_screen.dart';
import 'package:cure_app/screens/patient_order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cure_app/providers/orders_provider.dart';
import 'package:cure_app/utils/helpers.dart';
import 'package:cure_app/utils/constants.dart'; // ✅ لاستخدام ثوابت ودوال الحالة وقوائم الأسباب
import 'dart:ui';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  // =========================================================================
  // 💡 دوال الحوار الجديدة (Dialogs) مع إدخال السبب
  // =========================================================================

  // 1. دالة الحوار الخاصة بالإلغاء
  void _showCancelDialog(BuildContext context, dynamic order) {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    String? selectedReason = patientCancellationReasons.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب', style: TextStyle(color: kErrorColor)),
        content: _ActionDialogContent(
          reasonsList: patientCancellationReasons,
          onReasonChanged: (reason) => selectedReason = reason,
          isComplaint: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (selectedReason != null) {
                ordersProvider.cancelOrder(order.id, selectedReason!, context);
              } else {
                showSnackBar(context, 'الرجاء اختيار سبب للإلغاء.', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }

  // 2. دالة الحوار الخاصة بطلب الاسترداد
  void _showRefundDialog(BuildContext context, dynamic order) {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    // يمكن استخدام أسباب 'service_incomplete' كأسباب أولية للاسترداد من جهة المريض
    String? selectedReason = incompleteServiceReasons.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب استرداد', style: TextStyle(color: Colors.purple)),
        content: _ActionDialogContent(
          reasonsList: incompleteServiceReasons,
          onReasonChanged: (reason) => selectedReason = reason,
          isComplaint: true, // يمكن استخدام حقل النص للإضافة
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
               if (selectedReason != null) {
                ordersProvider.requestRefund(order.id, selectedReason!, context);
              } else {
                showSnackBar(context, 'الرجاء اختيار سبب لطلب الاسترداد.', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('تأكيد الطلب'),
          ),
        ],
      ),
    );
  }

  // 3. دالة الحوار الخاصة بتقديم شكوى/نزاع
  void _showComplaintDialog(BuildContext context, dynamic order) {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    // نستخدم الأسباب العامة أو نركز على حقل الإدخال
    String? complaintDetails = ''; 

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقديم شكوى/نزاع', style: TextStyle(color: Colors.deepOrange)),
        content: _ActionDialogContent(
          reasonsList: nurseRejectionReasons, // يمكن استخدامها كأمثلة
          onDetailsChanged: (details) => complaintDetails = details,
          isComplaint: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (complaintDetails!.trim().isNotEmpty) {
                ordersProvider.fileComplaint(order.id, complaintDetails!, context);
              } else {
                showSnackBar(context, 'الرجاء إدخال تفاصيل الشكوى.', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: const Text('تأكيد الشكوى'),
          ),
        ],
      ),
    );
  }

// ✅ دالة إنشاء أزرار تأكيد وصول الممرض
Widget _buildNurseArrivalConfirmationButtons(dynamic order) {
  // إذا تم التأكيد بالفعل، لا نعرض الأزرار
  if (order.isNurseArrivalConfirmedByPatient == true) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Text(
            '✅ تم تأكيد وصول الممرض',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  return Column(
    children: [
      // زر تأكيد وصول الممرض
      _styledArrivalButton(
        '✅ تأكيد وصول الممرض',
        () => _confirmNurseArrival(context, order),
        color: Colors.green,
        icon: Icons.person_pin_circle,
      ),
      const SizedBox(height: 8),
      
      // زر رفض/إبلاغ
      _outlinedArrivalButton(
        '❌ الممرض لم يصل',
        () => _reportNurseNotArrived(context, order),
        color: Colors.orange,
        icon: Icons.timer_off,
      ),
      
      const SizedBox(height: 8),
      
      // زر إبلاغ عن ممرض غير صحيح
      _outlinedArrivalButton(
        '🚫 الممرض ليس الذي طلبته',
        () => _reportWrongNurse(context, order),
        color: Colors.red,
        icon: Icons.warning_amber,
      ),
    ],
  );
}

// ✅ دالة تأكيد وصول الممرض
Future<void> _confirmNurseArrival(BuildContext context, dynamic order) async {
  final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
  
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person_pin_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('تأكيد وصول الممرض'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 40),
                SizedBox(height: 12),
                Text(
                  'هل تؤكد أن الممرض وصل إلى موقعك؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'سيتم إعلام الممرض وبدء الخدمة',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('ليس الآن'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.check),
          label: const Text('نعم، وصل'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      await ordersProvider.confirmNurseArrival(order.id);
      if (mounted) {
        showSnackBar(context, '✅ تم تأكيد وصول الممرض بنجاح');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '❌ فشل في تأكيد الوصول: $e', isError: true);
      }
    }
  }
}

// ✅ دالة الإبلاغ عن عدم وصول الممرض
Future<void> _reportNurseNotArrived(BuildContext context, dynamic order) async {
  final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
  
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.timer_off, color: Colors.orange),
          SizedBox(width: 8),
          Text('الإبلاغ عن عدم الوصول'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.timer_off, color: Colors.orange, size: 40),
                SizedBox(height: 12),
                Text(
                  'هل تريد الإبلاغ أن الممرض لم يصل بعد؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'سيتم إرسال تنبيه للممرض والدعم الفني',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('تراجع'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.report),
          label: const Text('تأكيد الإبلاغ'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      await ordersProvider.reportNurseNotArrived(order.id);
      if (mounted) {
        showSnackBar(context, '📨 تم الإبلاغ عن عدم الوصول');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '❌ فشل في الإبلاغ: $e', isError: true);
      }
    }
  }
}

// ✅ دالة الإبلاغ عن ممرض غير صحيح
Future<void> _reportWrongNurse(BuildContext context, dynamic order) async {
  final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
  
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red),
          SizedBox(width: 8),
          Text('الإبلاغ عن ممرض غير صحيح'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.warning_amber, color: Colors.red, size: 40),
                SizedBox(height: 12),
                Text(
                  'هل تريد الإبلاغ أن الممرض الحالي ليس الذي طلبته؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'سيتم إرسال تنبيه عاجل للدعم الفني',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('تراجع'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.flag),
          label: const Text('تأكيد الإبلاغ'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      await ordersProvider.reportWrongNurse(order.id);
      if (mounted) {
        showSnackBar(context, '🚨 تم الإبلاغ عن ممرض غير صحيح');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '❌ فشل في الإبلاغ: $e', isError: true);
      }
    }
  }
}

// ✅ دالة مساعدة لزر التأكيد
Widget _styledArrivalButton(String label, VoidCallback onPressed,
    {Color? color, IconData? icon}) {
  return Container(
    width: double.infinity,
    height: 50,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: (color ?? Colors.green).withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.check, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

// ✅ دالة مساعدة لزر الإبلاغ
Widget _outlinedArrivalButton(String label, VoidCallback onPressed,
    {Color? color, IconData? icon}) {
  return SizedBox(
    width: double.infinity,
    height: 45,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? Colors.orange,
        side: BorderSide(color: (color ?? Colors.orange).withOpacity(0.7), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.report, size: 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color ?? Colors.orange,
        ),
      ),
    ),
  );
}
  // 4. الدالة المساعدة لإنشاء الأزرار التفاعلية
  Widget _buildOrderActions(dynamic order) {
    final currentStatus = order.status;
    const isPatient = true; // نفترض أن هذه شاشة المريض

    final showCancel = canCancelOrder(currentStatus, isPatient: isPatient);
    final showRate = canRateOrder(currentStatus) && !(order.isRated ?? false);

    // Logic for Refund Request Button (based on user's table: "بعد completed أو service_incomplete")
    final showRefundRequestButton = (currentStatus == orderStatusCompleted || currentStatus == orderStatusServiceIncomplete) &&
        currentStatus != orderStatusRefundRequested && currentStatus != orderStatusRefunded;

    // Logic for Complaint/Dispute button
    final showComplaintButton = isActiveOrder(currentStatus) || 
        currentStatus == orderStatusCompleted || 
        currentStatus == orderStatusServiceIncomplete || 
        needsAdminIntervention(currentStatus);


    if (!showCancel && !showRate && !showRefundRequestButton && !showComplaintButton) {
      return const SizedBox.shrink(); 
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.start,
        children: [
          // 1. زر الإلغاء (للمريض في المراحل الأولى)
          if (showCancel)
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(context, order), // ✅ ربط الإجراء
                icon: const Icon(Icons.close, size: 18, color: kErrorColor),
                label: const Text('إلغاء الطلب',
                    style: TextStyle(color: kErrorColor, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  side: const BorderSide(color: kErrorColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

          // 2. زر التقييم (بعد اكتمال الخدمة فقط)
          if (showRate)
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              LeaveReviewScreen(order: order)));
                },
                icon: const Icon(Icons.star_rate_rounded,
                    size: 18, color: Colors.white),
                label: const Text('قيّم الخدمة',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),

          // 3. زر طلب استرداد (بعد completed أو service_incomplete)
          if (showRefundRequestButton)
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () => _showRefundDialog(context, order), // ✅ ربط الإجراء
                icon: const Icon(Icons.receipt_long,
                    size: 18, color: Colors.purple),
                label: const Text('طلب استرداد',
                    style: TextStyle(color: Colors.purple, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  side: const BorderSide(color: Colors.purple),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

          // 4. زر تقديم شكوى/نزاع
          if (showComplaintButton)
            SizedBox(
              height: 40,
              child: TextButton.icon(
                onPressed: () => _showComplaintDialog(context, order), // ✅ ربط الإجراء
                icon: const Icon(Icons.flag_outlined,
                    size: 18, color: Colors.deepOrange),
                label: const Text('شكوى/نزاع',
                    style: TextStyle(color: Colors.deepOrange, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildFilterChips(),
              const SizedBox(height: 20),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Consumer<OrdersProvider>(
                      builder: (context, ordersProvider, child) {
                        if (ordersProvider.isLoading) {
                          return _buildLoadingState();
                        } else if (ordersProvider.errorMessage != null) {
                          return _buildErrorState(ordersProvider);
                        } else if (ordersProvider.userOrders.isEmpty) {
                          return _buildEmptyState();
                        } else {
                          final filteredOrders =
                              _getFilteredOrders(ordersProvider.userOrders);
                          return _buildOrdersList(filteredOrders);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color.fromARGB(0, 143, 40, 40),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.15),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color:
                      const Color.fromARGB(255, 105, 53, 53).withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: const Color.fromARGB(255, 120, 40, 40).withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'سجل الطلبات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.2),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color.fromARGB(255, 74, 16, 16)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientBackground() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color.fromARGB(255, 98, 116, 255),
          const Color.fromARGB(255, 140, 146, 255),
          const Color.fromARGB(255, 131, 148, 255),
          const Color.fromARGB(255, 166, 174, 244),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ),
    );
  }

  Widget _buildFilterChips() {
    // ✅ تحديث الفلاتر لتعكس المجموعات الجديدة
    final filters = [
      {'key': 'all', 'label': 'الكل', 'icon': Icons.list_alt},
      {'key': orderStatusPending, 'label': 'في الانتظار', 'icon': Icons.hourglass_empty},
      {'key': 'active', 'label': 'نشط', 'icon': Icons.directions},
      {'key': orderStatusCompleted, 'label': 'مكتمل', 'icon': Icons.done_all},
      {'key': 'admin', 'label': 'نزاع/إداري', 'icon': Icons.admin_panel_settings},
      {'key': 'cancelled_rejected', 'label': 'ملغي/مرفوض', 'icon': Icons.cancel},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['key'];
          return Container(
            margin: const EdgeInsets.only(right: 10),
            child: FilterChip(
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['key'] as String;
                });
              },
              avatar: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color.fromARGB(255, 86, 128, 255).withOpacity(0.3)
                      : const Color.fromARGB(255, 70, 107, 255)
                          .withOpacity(0.1),
                ),
                child: Icon(
                  filter['icon'] as IconData,
                  size: 14,
                  color: const Color.fromARGB(255, 0, 0, 0),
                ),
              ),
              label: Text(
                filter['label'] as String,
                style: const TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.white.withOpacity(0.1),
              selectedColor: Colors.white.withOpacity(0.25),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ✅ تحديث منطق التصفية لاستخدام الدوال الجديدة
  List<dynamic> _getFilteredOrders(List<dynamic> orders) {
    if (_selectedFilter == 'all') return orders;

    return orders.where((order) {
      switch (_selectedFilter) {
        case 'active':
          return isActiveOrder(order.status);
        case 'admin':
          return needsAdminIntervention(order.status);
        case 'cancelled_rejected':
          // جميع الحالات النهائية التي ليست مكتملة أو مستردة
          return isTerminalStatus(order.status) &&
              order.status != orderStatusCompleted &&
              order.status != orderStatusRefunded;
        case orderStatusPending:
          return order.status == orderStatusPending;
        case orderStatusCompleted:
          return order.status == orderStatusCompleted;
        default:
          // مطابقة مباشرة للحالات الأخرى (مثل expired, refunded, etc.)
          return order.status == _selectedFilter;
      }
    }).toList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                SizedBox(height: 16),
                Text(
                  'جاري التحميل...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(OrdersProvider ordersProvider) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.3),
                        Colors.redAccent.withOpacity(0.2),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.error_outline,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  ordersProvider.errorMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ordersProvider.fetchUserOrders(),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      color: Colors.white, size: 50),
                ),
                const SizedBox(height: 24),
                const Text(
                  'لا توجد طلبات سابقة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ابدأ بطلب خدمة جديدة',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<dynamic> orders) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order, index);
      },
    );
  }

  Widget _buildOrderCard(dynamic order, int index) {
    final currentStatus = order.status;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PatientOrderDetailsScreen(order: order),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildOrderHeader(order),
                              const SizedBox(height: 16),
                              _buildDivider(),
                              const SizedBox(height: 16),
                              _buildOrderInfo(order),
                              _buildOrderActions(order),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderHeader(dynamic order) {
    final currentStatus = order.status;
    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Icon(getOrderStatusIcon(currentStatus), // ✅ استخدام أيقونة الحالة الجديدة
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'طلب بتاريخ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatDateTime(order.orderDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _buildStatusBadge(currentStatus), // ✅ تمرير الحالة مباشرة
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = getOrderStatusColor(status); // ✅ استخدام دالة اللون الجديدة
    final text = getOrderStatusText(status); // ✅ استخدام دالة النص الجديدة

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.2),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle( // ✅ استخدام TextStyle بدلاً من const TextStyle للسماح بتغيير اللون
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOrderInfo(dynamic order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.status == orderStatusAccepted && order.nurseName != null) // ✅ استخدام الثابت الجديد
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF007AFF).withOpacity(0.3),
                        const Color(0xFF007AFF).withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الممرض المسؤول',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        order.nurseName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [
                      Color.fromARGB(255, 89, 138, 244),
                      Color.fromARGB(255, 130, 255, 113)
                    ],
                  ),
                ),
                child: const Icon(Icons.attach_money,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإجمالي',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${order.totalPrice.toStringAsFixed(2)} جنيه مصري',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 💡 ويدجت داخلي جديد: محتوى حوار الإجراءات مع إدخال السبب
// =========================================================================

class _ActionDialogContent extends StatefulWidget {
  final List<String> reasonsList;
  final Function(String?)? onReasonChanged;
  final Function(String)? onDetailsChanged;
  final bool isComplaint;

  const _ActionDialogContent({
    required this.reasonsList,
    this.onReasonChanged,
    this.onDetailsChanged,
    this.isComplaint = false,
  });

  @override
  _ActionDialogContentState createState() => _ActionDialogContentState();
}

class _ActionDialogContentState extends State<_ActionDialogContent> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.reasonsList.isNotEmpty ? widget.reasonsList.first : null;
    if (widget.onReasonChanged != null) {
      widget.onReasonChanged!(_selectedReason);
    }
    _detailsController.addListener(_onDetailsChanged);
  }

  @override
  void dispose() {
    _detailsController.removeListener(_onDetailsChanged);
    _detailsController.dispose();
    super.dispose();
  }

  void _onDetailsChanged() {
    if (widget.onDetailsChanged != null) {
      widget.onDetailsChanged!(_detailsController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الرجاء اختيار السبب:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedReason,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
            hint: const Text('اختر سبباً'),
            items: widget.reasonsList.map((String reason) {
              return DropdownMenuItem<String>(
                value: reason,
                child: Text(reason),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedReason = newValue;
              });
              if (widget.onReasonChanged != null) {
                widget.onReasonChanged!(newValue);
              }
            },
          ),
          
          if (widget.isComplaint) ...[
            const SizedBox(height: 20),
            const Text('ملاحظات إضافية (مطلوب للشكوى):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'أدخل تفاصيل الشكوى هنا...',
              ),
              validator: (value) {
                if (widget.isComplaint && (value == null || value.isEmpty)) {
                  return 'الرجاء إدخال تفاصيل الشكوى.';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}
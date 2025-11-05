// lib/screens/order_tracking_screen.dart

import 'dart:async';
import 'package:cure_app/models/order.dart';
import 'package:cure_app/providers/orders_provider.dart';
import 'package:cure_app/screens/home_screen.dart';
import 'package:cure_app/screens/leave_review_screen.dart';
import 'package:cure_app/screens/report.dart';
import 'package:cure_app/services/firestore_service.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:cure_app/utils/order_statuses.dart';
import 'package:cure_app/utils/helpers.dart';
import 'package:cure_app/widgets/loading_indicator.dart';
import 'package:cure_app/widgets/ripple_animation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  Timer? _countdownTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _lastStatus;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Duration _remainingTime = Duration.zero;

  Future<void> _playStatusChangeSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/0.mp3'));
    } catch (e) {
      debugPrint('خطأ في تشغيل الصوت: $e');
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      debugPrint('خطأ في تشغيل الصوت: $e');
    }
  }

  Future<void> _clearActiveOrderAndExit({bool clearActiveOrder = true}) async {
    _timer?.cancel();
    _countdownTimer?.cancel();

    if (clearActiveOrder) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('activeOrderId');
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      try {
        final ordersProvider = context.read<OrdersProvider>();
        await ordersProvider.cancelOrder(
            widget.orderId, 'إلغاء من شاشة التتبع', context);
        await _clearActiveOrderAndExit();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في إلغاء الطلب: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ دالة طلب التأكيد من الممرض (محدثة)
  Future<void> _requestMovementConfirmation(
      BuildContext context, Order order) async {
    final ordersProvider = context.read<OrdersProvider>();

    if (order.isNurseMovingRequested == true) {
      showSnackBar(context, 'لقد طلبت التأكيد بالفعل. يرجى الانتظار.',
          isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.directions_car, color: kPrimaryColor),
            SizedBox(width: 8),
            Text('طلب تأكيد التحرك'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.info_outline, color: kPrimaryColor, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'هل تطلب من الممرض تأكيد تحركه؟',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'سيتم إرسال تنبيه للممرض لتأكيد أنه في طريقه إليك',
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
              backgroundColor: kPrimaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.send),
            label: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ordersProvider.requestNurseMovementConfirmation(order.id);
      showSnackBar(context, '📨 تم إرسال طلب التأكيد للممرض');
    }
  }

  // ✅ تأكيد رؤية الممرض يتحرك
  Future<void> _confirmNurseMovement(BuildContext context, Order order) async {
    final ordersProvider = context.read<OrdersProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.visibility, color: Colors.green),
            SizedBox(width: 8),
            Text('تأكيد رؤية الممرض'),
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
                    'هل ترى الممرض يتحرك نحو موقعك؟',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'سيتم إعلام الممرض بأنك تراه في الطريق',
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
            child: const Text('ليس بعد'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.check),
            label: const Text('نعم، أراه'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final firestoreService = context.read<FirestoreService>();
      await firestoreService.patientConfirmsNurseMoving(order.id);
      showSnackBar(context, '✅ تم تأكيد رؤية الممرض');
    }
  }

  // 🆕🆕🆕 دوال تأكيد وصول الممرض والإبلاغ
  Future<void> _confirmNurseArrival(BuildContext context, Order order) async {
    final ordersProvider = context.read<OrdersProvider>();

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
      final success = await ordersProvider.confirmNurseArrival(order.id);
      if (success && mounted) {
        showSnackBar(context, '✅ تم تأكيد وصول الممرض بنجاح');
      }
    }
  }

  Future<void> _reportNurseNotArrived(BuildContext context, Order order) async {
    final ordersProvider = context.read<OrdersProvider>();

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
      final success = await ordersProvider.reportNurseNotArrived(order.id);
      if (success && mounted) {
        showSnackBar(context, '📨 تم الإبلاغ عن عدم الوصول');
      }
    }
  }

  Future<void> _reportWrongNurse(BuildContext context, Order order) async {
    final ordersProvider = context.read<OrdersProvider>();

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
      final success = await ordersProvider.reportWrongNurse(order.id);
      if (success && mounted) {
        showSnackBar(context, '🚨 تم الإبلاغ عن ممرض غير صحيح');
      }
    }
  }

  // 🆕🆕🆕 دالة إنشاء أزرار تأكيد وصول الممرض
  Widget _buildNurseArrivalConfirmationButtons(Order order) {
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
        _styledButton(
          '✅ تأكيد وصول الممرض',
          () => _confirmNurseArrival(context, order),
          color: Colors.green,
          icon: Icons.person_pin_circle,
        ),
        const SizedBox(height: 8),

        // زر رفض/إبلاغ
        _outlinedButton(
          '❌ الممرض لم يصل',
          () => _reportNurseNotArrived(context, order),
          color: Colors.orange,
          icon: Icons.timer_off,
        ),

        const SizedBox(height: 8),

        // زر إبلاغ عن ممرض غير صحيح
        _outlinedButton(
          '🚫 الممرض ليس الذي طلبته',
          () => _reportWrongNurse(context, order),
          color: Colors.red,
          icon: Icons.warning_amber,
        ),
      ],
    );
  }

  void _navigateToReport(Order order) {
    if (order.nurseId == null || order.nurseId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لا يمكن الإبلاغ عن مشكلة لطلب بدون ممرض.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          nurseId: order.nurseId!,
          orderId: order.id,
        ),
      ),
    );
  }

  bool _isArabicName(String name) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(name);
  }

  // ✅ المنطق: حساب الوقت المتبقي للإلغاء
  void _calculateCancellationTime(Order order) {
    if (order.status == OrderStatus.accepted &&
        order.cancellationAvailableAt != null) {
      final now = DateTime.now();
      final availableTime = order.cancellationAvailableAt!;

      if (now.isBefore(availableTime)) {
        _remainingTime = availableTime.difference(now);
      } else {
        _remainingTime = Duration.zero;
      }
    }
  }

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
    _animationController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) setState(() {});
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('تتبع الطلب',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22)),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
        ),
        body: StreamBuilder<Order?>(
          stream: firestoreService.getOrderStream(widget.orderId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingIndicator();
            }
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('الطلب غير موجود أو تم حذفه.'));
            }

            final order = snapshot.data!;

            _calculateCancellationTime(order);

            if (_lastStatus != null && _lastStatus != order.status) {
              _playStatusChangeSound();
              _animationController.reset();
              _animationController.forward();
            }
            _lastStatus = order.status;

            return _buildOrderStatusView(order, firestoreService);
          },
        ),
      ),
    );
  }

  Widget _buildOrderStatusView(Order order, FirestoreService firestoreService) {
    final bool canCancel = order.canPatientCancelAfterAccept == true ||
        _remainingTime.inSeconds <= 0;

    switch (order.status) {
      case OrderStatus.pending:
        return _buildStatusView(
          order: order,
          customWidget: const RippleAnimation(
            color: kPrimaryColor,
            child: Icon(Icons.search, color: Colors.white, size: 50),
          ),
          title: 'جاري البحث عن ممرض...',
          subtitle: const Text('طلبك قيد المراجعة'),
          message: 'تم إرسال طلبك بنجاح، وسنبلغك عند قبول أحد مقدمي الخدمة.',
          progress: 0.2,
          progressColor: kPrimaryColor,
          statusBadge: 'قيد الانتظار',
          statusBadgeColor: Colors.orange,
          showCancelButton: true,
          actions: [
            _styledButton('العودة إلى الرئيسية',
                () => _clearActiveOrderAndExit(clearActiveOrder: false),
                color: kPrimaryColor, icon: Icons.home)
          ],
        );

      case OrderStatus.accepted:
        return _buildStatusView(
          order: order,
          icon: order.isNurseMovingConfirmed == true
              ? Icons.directions_car_filled
              : Icons.directions_car_outlined,
          color: order.isNurseMovingConfirmed == true
              ? kSuccessColor
              : const Color(0xFF4CAF50),
          title: order.isNurseMovingConfirmed == true
              ? 'الممرض في الطريق إليك'
              : 'تم قبول الطلب',
          subtitle: _buildNurseNameWidget(order.nurseName),
          message: order.isNurseMovingConfirmed == true
              ? 'الممرض في طريقه إليك الآن. يرجى البقاء على اتصال.'
              : 'تم قبول طلبك! يمكنك الآن طلب تأكيد التحرك من الممرض.',
          progress: 0.6,
          progressColor: kSuccessColor,
          statusBadge: order.isNurseMovingConfirmed == true
              ? OrderStatus.onTheWay
              : OrderStatus.accepted,
          statusBadgeColor: order.isNurseMovingConfirmed == true
              ? kSuccessColor
              : const Color(0xFF4CAF50),
          showCancelButton: canCancel,
          isReportCancel: canCancel,
          actions: [
            // 🆕 بانر طلب تأكيد التحرك النابض
            if (order.isNurseMovingRequested == true &&
                order.isNurseMovingConfirmed != true)
              _buildMovementRequestBanner(),

            // زر تأكيد رؤية الممرض
            if (order.isNurseMovingConfirmed == true &&
                order.patientConfirmedNurseMoving != true)
              _buildMovementConfirmationButton(order),

            if (!canCancel && _remainingTime.inSeconds > 0)
              _buildCountdownTimerWidget(context),

            _buildMovementRequestButton(order, canCancel),

            const SizedBox(height: 12),
            _buildCancellationButton(order, canCancel),
          ],
        );

      case OrderStatus.arrived:
        return _buildStatusView(
          order: order,
          icon: Icons.location_on,
          color: Colors.blue,
          title: 'الممرض وصل إلى موقعك',
          subtitle: _buildNurseNameWidget(order.nurseName),
          message: order.isNurseArrivalConfirmedByPatient == true
              ? 'تم تأكيد وصول الممرض وسيبدأ في تقديم الخدمة الطبية قريباً.'
              : 'وصل الممرض إلى عنوانك. يرجى التأكد من هوية الممرض والمطابقة مع الطلب.',
          progress: 0.8,
          progressColor: Colors.blue,
          statusBadge: order.status,
          statusBadgeColor: Colors.blue,
          isReportCancel: true,
          actions: [
            // 🆕 أزرار تأكيد وصول الممرض
            _buildNurseArrivalConfirmationButtons(order),

            const SizedBox(height: 12),

            // 🆕 تدفق الدفع النقدي المحسن
            if (order.paymentMethod == paymentMethodCash)
              _buildCashPaymentFlow(order),

            const SizedBox(height: 12),

            _outlinedButton('العودة إلى الرئيسية',
                () => _clearActiveOrderAndExit(clearActiveOrder: false),
                icon: Icons.home_outlined)
          ],
        );

      case OrderStatus.inProgress:
        return _buildStatusView(
          order: order,
          icon: Icons.medical_services,
          color: Colors.deepPurple,
          title: 'جاري تقديم الخدمة',
          subtitle: _buildNurseNameWidget(order.nurseName),
          message:
              'الخدمة الطبية قيد التنفيذ الآن. يرجى الانتظار حتى انتهاء الممرض.',
          progress: 0.9,
          progressColor: Colors.deepPurple,
          statusBadge: order.status,
          statusBadgeColor: Colors.deepPurple,
          isReportCancel: true,
          actions: [
            if (order.paymentMethod == paymentMethodCash)
              _buildCashPaymentFlow(order),
            _outlinedButton('العودة إلى الرئيسية',
                () => _clearActiveOrderAndExit(clearActiveOrder: false),
                icon: Icons.home_outlined)
          ],
        );

      case OrderStatus.completed:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _playSuccessSound();
        });

        return _buildStatusView(
          order: order,
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'تم إكمال الخدمة بنجاح',
          subtitle: const Text('شكراً لاستخدامك خدماتنا'),
          message: 'تم إكمال الخدمة الطبية بنجاح. نتمنى لك الشفاء العاجل.',
          progress: 1.0,
          progressColor: Colors.green,
          statusBadge: OrderStatus.completed,
          statusBadgeColor: Colors.green,
          actions: [
            _styledButton('تقييم الخدمة', () => _navigateToReview(order),
                color: kPrimaryColor, icon: Icons.star_outline),
            const SizedBox(height: 12),
            _outlinedButton(
                'العودة إلى الرئيسية', () => _clearActiveOrderAndExit(),
                icon: Icons.home_outlined),
          ],
        );

      case OrderStatus.cancelled:
      case OrderStatus.rejected:
      case OrderStatus.cancelledByPatient:
      case OrderStatus.cancelledByNurse:
        return _buildStatusView(
          order: order,
          icon: Icons.cancel_outlined,
          color: Colors.red,
          title: 'تم إلغاء الطلب',
          subtitle: const Text('الطلب ملغي'),
          message: 'تم إلغاء طلبك. يمكنك إنشاء طلب جديد في أي وقت.',
          progress: 0.0,
          progressColor: Colors.red,
          statusBadge: OrderStatus.cancelled,
          statusBadgeColor: Colors.red,
          actions: [
            _styledButton('طلب جديد', () => _clearActiveOrderAndExit(),
                color: kPrimaryColor, icon: Icons.add)
          ],
        );

      default:
        return _buildStatusView(
          order: order,
          icon: Icons.info_outline,
          color: Colors.grey,
          title: 'حالة الطلب: ${order.status}',
          subtitle: const Text('حالة غير معروفة'),
          message:
              'يوجد مشكلة في تحديد حالة الطلب. يرجى التواصل مع الدعم الفني.',
          progress: 0.5,
          progressColor: Colors.grey,
          statusBadge: order.status,
          statusBadgeColor: Colors.grey,
          actions: [
            _outlinedButton(
                'العودة إلى الرئيسية', () => _clearActiveOrderAndExit(),
                icon: Icons.home_outlined)
          ],
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🆕 مكونات التكامل الديناميكي بين المريض والممرض
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMovementRequestBanner() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_car,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📨 انتظار تأكيد الممرض',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'لقد طلبت تأكيد التحرك، يرجى الانتظار...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementConfirmationButton(Order order) {
    return _styledButton(
      'أرى الممرض يتحرك - تأكيد',
      () => _confirmNurseMovement(context, order),
      color: Colors.green,
      icon: Icons.visibility,
    );
  }

  Widget _buildCashPaymentFlow(Order order) {
    // حالة: لم يطلب الدفع بعد
    if (order.isCashPaymentRequested != true) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'بانتظار طلب الدفع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'الممرض سيطلب منك تسليم ${order.finalPrice.toStringAsFixed(2)} ج.م',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // حالة: تم طلب الدفع
    return Column(
      children: [
        // بانر حالة الدفع
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: order.isPaymentConfirmedByPatient == true
                ? Colors.green.shade50
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: order.isPaymentConfirmedByPatient == true
                  ? Colors.green.shade200
                  : Colors.orange.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                order.isPaymentConfirmedByPatient == true
                    ? Icons.check_circle
                    : Icons.access_time,
                color: order.isPaymentConfirmedByPatient == true
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.isPaymentConfirmedByPatient == true
                          ? '✅ تم تأكيد التسليم'
                          : '💳 طلب تسليم نقدي',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: order.isPaymentConfirmedByPatient == true
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.finalPrice.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // زر تأكيد الدفع
        if (order.isPaymentConfirmedByPatient != true)
          _buildCashConfirmationButton(context, order),
      ],
    );
  }

  Widget _buildCountdownTimerWidget(BuildContext context) {
    final minutes = _remainingTime.inMinutes;
    final seconds = _remainingTime.inSeconds % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            'زر الإلغاء يتفعل بعد: ',
            style: TextStyle(color: Colors.orange.shade900),
          ),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementRequestButton(Order order, bool canCancel) {
    if (order.isNurseMovingConfirmed == true) {
      return const SizedBox.shrink();
    }

    return _outlinedButton(
      order.isNurseMovingRequested == true
          ? '📨 تم إرسال طلب التأكيد'
          : '🚗 هل يتحرك الممرض الآن؟',
      order.isNurseMovingRequested == true
          ? () {}
          : () => _requestMovementConfirmation(context, order),
      icon: Icons.directions_car,
    );
  }

  Widget _buildCancellationButton(Order order, bool canCancel) {
    return _styledButton(
      canCancel ? '❌ إلغاء الطلب' : '⏳ انتظار تفعيل الإلغاء',
      canCancel ? () => _cancelOrder(order) : () {},
      color: canCancel ? Colors.red.shade700 : Colors.grey.shade400,
      icon: Icons.cancel_outlined,
    );
  }

  Widget _buildCashConfirmationButton(BuildContext context, Order order) {
    final ordersProvider = context.read<OrdersProvider>();

    return _styledButton(
      '✅ تأكيد تسليم النقدية',
      () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.handshake, color: Colors.green),
                SizedBox(width: 8),
                Text('تأكيد تسليم النقدية'),
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
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_wallet,
                          color: Colors.green, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        '${order.finalPrice.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'هل تؤكد أنك سلمت المبلغ النقدي للممرض؟',
                        style: TextStyle(
                          fontSize: 14,
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
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('نعم، تم التسليم'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await ordersProvider.patientConfirmsCashPayment(order.id);
          showSnackBar(context, '✅ تم تأكيد التسليم بنجاح.', isError: false);
        }
      },
      color: Colors.green,
      icon: Icons.handshake,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 مكونات الواجهة القياسية
  // ═══════════════════════════════════════════════════════════════════════════

  Widget? _buildNurseNameWidget(String? nurseName) {
    if (nurseName == null || nurseName.isEmpty) return null;
    final isArabic = _isArabicName(nurseName);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (isArabic) ...[
        Text('الممرض: ',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600])),
        Text(nurseName,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor)),
      ] else ...[
        Text(nurseName,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor)),
        Text(' :الممرض',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600])),
      ],
    ]);
  }

  void _navigateToReview(Order order) {
    Navigator.of(context)
        .push(
            MaterialPageRoute(builder: (_) => LeaveReviewScreen(order: order)))
        .then((_) {
      _clearActiveOrderAndExit();
    });
  }

  Widget _styledButton(String label, VoidCallback onPressed,
      {Color? color, IconData? icon}) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: (color ?? kPrimaryColor).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? kPrimaryColor,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.check, size: 20),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _outlinedButton(String label, VoidCallback onPressed,
      {IconData? icon, Color? color}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? kPrimaryColor,
          side: BorderSide(
              color: (color ?? kPrimaryColor).withOpacity(0.3), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_back, size: 18),
        label: Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color ?? kPrimaryColor,
            )),
      ),
    );
  }

  Widget _buildStatusView({
    required Order order,
    Widget? customWidget,
    IconData? icon,
    required String title,
    Widget? subtitle,
    required String message,
    Color? color,
    double progress = 0.0,
    Color? progressColor,
    String? statusBadge,
    Color? statusBadgeColor,
    List<Widget>? actions,
    bool showCancelButton = false,
    bool isReportCancel = false,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Progress Bar
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4)),
                child: Stack(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 1000),
                    width: MediaQuery.of(context).size.width * 0.9 * progress,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        progressColor ?? kPrimaryColor,
                        (progressColor ?? kPrimaryColor).withOpacity(0.7),
                      ]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // Main Content
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        if (statusBadge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: statusBadgeColor?.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                  color: statusBadgeColor?.withOpacity(0.3) ??
                                      Colors.grey,
                                  width: 1),
                            ),
                            child: Text(statusBadge,
                                style: TextStyle(
                                    color: statusBadgeColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        const SizedBox(height: 24),
                        customWidget ??
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color:
                                    (color ?? kPrimaryColor).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Icon(icon ?? Icons.info,
                                  size: 40, color: color ?? kPrimaryColor),
                            ),
                        const SizedBox(height: 24),
                        Text(title,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                                color: Colors.black87),
                            textAlign: TextAlign.center),
                        if (subtitle != null) ...[
                          const SizedBox(height: 12),
                          subtitle,
                        ],
                        const SizedBox(height: 16),
                        Text(message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                height: 1.5)),
                      ],
                    ),
                  ),

                  // Cancel/Report Button
                  if (showCancelButton)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.3), width: 1),
                        ),
                        child: IconButton(
                          onPressed: isReportCancel
                              ? () => _navigateToReport(order)
                              : () => _cancelOrder(order),
                          icon: Icon(
                              isReportCancel
                                  ? Icons.report_outlined
                                  : Icons.close,
                              color: Colors.red,
                              size: 18),
                          padding: EdgeInsets.zero,
                          tooltip:
                              isReportCancel ? 'إبلاغ عن مشكلة' : 'إلغاء الطلب',
                        ),
                      ),
                    ),
                ],
              ),

              // Action Buttons
              if (actions != null) ...[
                const SizedBox(height: 24),
                ...actions,
              ]
            ],
          ),
        ),
      ),
    );
  }
}

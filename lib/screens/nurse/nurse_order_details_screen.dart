import 'package:cure_app/models/order.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/providers/nurse_provider.dart';
import 'package:cure_app/services/communication_service.dart';
import 'package:cure_app/services/firestore_service.dart';
import 'package:cure_app/utils/helpers.dart';
import 'package:cure_app/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF5F5F5),
        title: const Text('تفاصيل الطلب',
            style: TextStyle(
                color: Colors.black87, fontSize: 18)), // تعديل لون النص
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color.fromARGB(255, 81, 112, 252)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<Order>(
        stream: firestoreService.getOrderStream(widget.initialOrder.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child:
                  Text('خطأ في تحميل البيانات', style: TextStyle(fontSize: 16)),
            );
          }

          final order = snapshot.data!;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCompactOrderCard(order),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactOrderCard(Order order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                _buildCompactSection(
                  title: 'بيانات المريض',
                  icon: Icons.person,
                  color: const Color(0xFF2196F3),
                  children: [
                    _buildCompactRow('اسم المريض', order.patientName),
                    _buildCompactRow('الهاتف', order.phoneNumber,
                        // ✅ تم استدعاء الدالة الجديدة هنا
                        action: _buildCircleIconButton(
                          icon: Icons.phone,
                          color: const Color(0xFF4CAF50),
                          onTap: () async {
                            try {
                              await CommunicationService.makePhoneCall(
                                  order.phoneNumber);
                            } catch (e) {
                              if (mounted)
                                showSnackBar(context, 'فشل في إجراء المكالمة',
                                    isError: true);
                            }
                          },
                        )),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCompactSection(
                  title: 'الموقع',
                  icon: Icons.location_on,
                  color: const Color(0xFFFF5722),
                  children: [
                    _buildCompactRow('العنوان', order.deliveryAddress,
                        isAddress: true,
                        // ✅ تم استدعاء الدالة الجديدة هنا
                        action: _buildCircleIconButton(
                          icon: Icons.map,
                          color: const Color(0xFF2196F3),
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
                            } catch (e) {
                              if (mounted)
                                showSnackBar(context, 'فشل في فتح الخرائط',
                                    isError: true);
                            }
                          },
                        )),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCompactSection(
                  title: 'الخدمات',
                  icon: Icons.medical_services,
                  color: const Color(0xFF9C27B0),
                  children: [
                    ...order.services
                        .map((service) => _buildServiceRow(service))
                        .toList(),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCompactSection(
                  title: 'التفاصيل',
                  icon: Icons.info,
                  color: const Color(0xFFFF9800),
                  children: [
                    _buildCompactRow(
                        'تاريخ الطلب', formatDateTime(order.orderDate)),
                    if (order.appointmentDate != null)
                      _buildCompactRow('موعد الخدمة',
                          formatDateTime(order.appointmentDate!)),
                    if (order.serviceProviderType != null &&
                        order.serviceProviderType != 'غير محدد')
                      _buildCompactRow('التفضيل', order.serviceProviderType!),
                    if (order.notes != null && order.notes!.isNotEmpty)
                      _buildCompactRow('ملاحظات', order.notes!, isNote: true),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTotalSection(order),
                const SizedBox(height: 16),
                _buildActionButtons(context, order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... الدوال الأخرى تبقى كما هي ...

  // ✅✅✅ دالة جديدة ومحسّنة لإنشاء أزرار الأيقونات ✅✅✅
  Widget _buildCircleIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6), // تم زيادة المساحة الداخلية
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8), // شكل دائري أكثر
        ),
        child: Icon(icon,
            color: Colors.white, size: 16), // ✅ تم تكبير الحجم من 12 إلى 16
      ),
    );
  }

  // ❌ تم حذف _buildPhoneButton و _buildMapButton

  // باقي الدوال المساعدة تبقى كما هي بدون تغيير
  Widget _buildOrderHeader(Order order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getStatusGradient(order.status),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
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
          if (action != null) ...[
            const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildServiceRow(dynamic service) {
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
              color: const Color(0xFF4CAF50),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
        ),
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

  Widget _buildActionButtons(BuildContext context, Order order) {
    final nurseProvider = Provider.of<NurseProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (nurseProvider.isLoading) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    switch (order.status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: _buildCompactButton(
                label: 'قبول',
                icon: Icons.check,
                color: const Color(0xFF4CAF50),
                onPressed: () async {
                  final success = await nurseProvider.acceptOrder(
                      order, authProvider.currentUserProfile!);
                  if (success && mounted) {
                    showSnackBar(context, 'تم قبول الطلب بنجاح');
                    Navigator.of(context).pop();
                  } else if (mounted) {
                    showSnackBar(
                        context, nurseProvider.errorMessage ?? 'حدث خطأ',
                        isError: true);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompactButton(
                label: 'رفض',
                icon: Icons.close,
                color: const Color(0xFFf44336),
                onPressed: () async {
                  final success = await nurseProvider.rejectOrder(order);
                  if (success && mounted) {
                    showSnackBar(context, 'تم رفض الطلب');
                    Navigator.of(context).pop();
                  } else if (mounted) {
                    showSnackBar(
                        context, nurseProvider.errorMessage ?? 'حدث خطأ',
                        isError: true);
                  }
                },
              ),
            ),
          ],
        );

      case 'accepted':
        return _buildCompactButton(
          label: 'لقد وصلت',
          icon: Icons.location_on,
          color: const Color(0xFFFF9800),
          onPressed: () => nurseProvider.markAsArrived(order),
          fullWidth: true,
        );

      case 'arrived':
        return _buildCompactButton(
          label: 'إنهاء الخدمة',
          icon: Icons.check_circle,
          color: const Color(0xFF2196F3),
          onPressed: () async {
            final success = await nurseProvider.completeOrder(order);
            if (success && mounted) {
              showSnackBar(context, 'تم إنهاء الخدمة بنجاح');
              Navigator.of(context).pop();
            } else if (mounted) {
              showSnackBar(context, nurseProvider.errorMessage ?? 'حدث خطأ',
                  isError: true);
            }
          },
          fullWidth: true,
        );

      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            'حالة الطلب: ${_getStatusText(order.status)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
    }
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
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

  List<Color> _getStatusGradient(String status) {
    switch (status) {
      case 'pending':
        return [const Color(0xFFFF9800), const Color(0xFFF57C00)];
      case 'accepted':
        return [const Color(0xFF2196F3), const Color(0xFF1976D2)];
      case 'arrived':
        return [const Color(0xFF4CAF50), const Color(0xFF388E3C)];
      case 'completed':
        return [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)];
      default:
        return [const Color(0xFF9E9E9E), const Color(0xFF757575)];
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.check_circle;
      case 'arrived':
        return Icons.location_on;
      case 'completed':
        return Icons.task_alt;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'في انتظار الموافقة';
      case 'accepted':
        return 'تم قبول الطلب';
      case 'arrived':
        return 'وصل المُمرض';
      case 'completed':
        return 'تم إنهاء الخدمة';
      default:
        return 'حالة غير محددة';
    }
  }
}

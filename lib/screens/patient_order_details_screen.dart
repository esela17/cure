import 'package:cure_app/models/order.dart';
import 'package:cure_app/models/user_model.dart';
import 'package:cure_app/screens/leave_review_screen.dart';
import 'package:cure_app/services/firestore_service.dart';
import 'package:cure_app/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class PatientOrderDetailsScreen extends StatefulWidget {
  final Order order;
  const PatientOrderDetailsScreen({super.key, required this.order});

  @override
  State<PatientOrderDetailsScreen> createState() =>
      _PatientOrderDetailsScreenState();
}

class _PatientOrderDetailsScreenState extends State<PatientOrderDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isMediumScreen = size.width >= 360 && size.width < 400;
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(context),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16.0 : 20.0,
                  vertical: 20.0,
                ),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isSmallScreen ? 16 : 20),

                    // قسم تفاصيل الممرض (يظهر فقط إذا تم قبول الطلب)
                    if (widget.order.nurseId != null)
                      FutureBuilder<UserModel?>(
                        future: firestoreService.getUser(widget.order.nurseId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildLoadingCard(isSmallScreen);
                          }
                          if (!snapshot.hasData || snapshot.data == null) {
                            return _buildErrorCard(
                                'لا يمكن تحميل بيانات الممرض', isSmallScreen);
                          }
                          final nurse = snapshot.data!;
                          return _buildNurseCard(nurse, isSmallScreen);
                        },
                      ),

                    SizedBox(height: isSmallScreen ? 20 : 24),

                    // قسم تفاصيل الطلب
                    _buildOrderDetailsCard(isSmallScreen),

                    SizedBox(height: isSmallScreen ? 24 : 30),

                    // زر تقييم الخدمة
                    if (widget.order.status == 'completed' &&
                        !widget.order.isRated)
                      _buildRatingButton(isSmallScreen),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      toolbarHeight: isSmallScreen ? 56 : 60,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.35),
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.15),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        'تفاصيل الطلب',
        style: TextStyle(
          color: Colors.white,
          fontSize: isSmallScreen ? 20 : 22,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.4),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      leading: Container(
        margin: EdgeInsets.all(isSmallScreen ? 6 : 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: isSmallScreen ? 20 : 22,
          ),
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
          const Color(0xFF667eea),
          const Color(0xFF764ba2),
          const Color(0xFF89609e),
          const Color(0xFFa8edea),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ),
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    bool isSmallScreen = false,
  }) {
    return Container(
      margin: margin ?? EdgeInsets.only(bottom: isSmallScreen ? 16 : 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: padding ?? EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.35),
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(-10, -10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(bool isSmallScreen) {
    return _buildGlassCard(
      isSmallScreen: isSmallScreen,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 30.0 : 40.0),
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: isSmallScreen ? 2.5 : 3,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message, bool isSmallScreen) {
    return _buildGlassCard(
      isSmallScreen: isSmallScreen,
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 45 : 50,
            height: isSmallScreen ? 45 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.9),
                  Colors.redAccent.withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.error_outline,
              color: Colors.white,
              size: isSmallScreen ? 22 : 24,
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNurseCard(UserModel nurse, bool isSmallScreen) {
    return _buildGlassCard(
      isSmallScreen: isSmallScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'مقدم الخدمة', Icons.medical_services, isSmallScreen),
          SizedBox(height: isSmallScreen ? 16 : 20),
          Row(
            children: [
              Container(
                width: isSmallScreen ? 60 : 70,
                height: isSmallScreen ? 60 : 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.4),
                      Colors.white.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: nurse.profileImageUrl != null
                      ? Image.network(
                          nurse.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person,
                            color: Colors.white,
                            size: isSmallScreen ? 30 : 35,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: Colors.white,
                          size: isSmallScreen ? 30 : 35,
                        ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nurse.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Row(
                      children: [
                        RatingBarIndicator(
                          rating: nurse.averageRating,
                          itemBuilder: (context, index) => const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFD700),
                          ),
                          itemCount: 5,
                          itemSize: isSmallScreen ? 18.0 : 22.0,
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6 : 8,
                            vertical: isSmallScreen ? 3 : 4,
                          ),
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
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '(${nurse.ratingCount})',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard(bool isSmallScreen) {
    return _buildGlassCard(
      isSmallScreen: isSmallScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('تفاصيل طلبك', Icons.receipt_long, isSmallScreen),
          SizedBox(height: isSmallScreen ? 16 : 20),
          _buildDetailRow(
            Icons.tag,
            'رقم الطلب:',
            widget.order.id.substring(0, 8),
            isSmallScreen: isSmallScreen,
          ),
          _buildDetailRow(
            Icons.calendar_today_rounded,
            'تاريخ الطلب:',
            formatDateTime(widget.order.orderDate),
            isSmallScreen: isSmallScreen,
          ),
          _buildDetailRow(
            Icons.info_outline_rounded,
            'الحالة:',
            widget.order.status,
            statusColor: _getStatusColor(widget.order.status),
            showStatusBadge: true,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          _buildDivider(),
          SizedBox(height: isSmallScreen ? 16 : 20),
          // ... في دالة _buildOrderDetailsCard
          _buildSectionHeader('الخدمات المطلوبة', Icons.medical_information,
              isSmallScreen, // <-- تم وضعها هنا في الموضع الثالث
              isSubSection: true),
// ...
          SizedBox(height: isSmallScreen ? 12 : 16),
          ...widget.order.services
              .map((service) => _buildServiceItem(service, isSmallScreen)),
          SizedBox(height: isSmallScreen ? 16 : 20),
          _buildDivider(),
          SizedBox(height: isSmallScreen ? 16 : 20),
          _buildTotalRow(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isSmallScreen,
      {bool isSubSection = false}) {
    return Row(
      children: [
        Container(
          width: isSmallScreen
              ? (isSubSection ? 35 : 40)
              : (isSubSection ? 40 : 45),
          height: isSmallScreen
              ? (isSubSection ? 35 : 40)
              : (isSubSection ? 40 : 45),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.4),
                Colors.white.withOpacity(0.2),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: isSmallScreen
                ? (isSubSection ? 18 : 20)
                : (isSubSection ? 20 : 22),
          ),
        ),
        SizedBox(width: isSmallScreen ? 10 : 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen
                  ? (isSubSection ? 16 : 18)
                  : (isSubSection ? 18 : 22),
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? statusColor,
    bool showStatusBadge = false,
    required bool isSmallScreen,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10.0 : 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: isSmallScreen ? 30 : 35,
            height: isSmallScreen ? 30 : 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white.withOpacity(0.9),
              size: isSmallScreen ? 16 : 18,
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: showStatusBadge
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStatusBadge(
                              value, statusColor!, isSmallScreen),
                        )
                      : Text(
                          value,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: statusColor ?? Colors.white,
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: statusColor != null
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color, bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: status == 'pending' ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 12,
              vertical: isSmallScreen ? 5 : 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.9),
                  color.withOpacity(0.5),
                ],
              ),
              border: Border.all(
                color: color.withOpacity(0.1),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.9),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _getStatusText(status),
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: color.withOpacity(0.8),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceItem(dynamic service, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 15),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 6 : 8,
            height: isSmallScreen ? 6 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: Text(
              service.name,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 12,
              vertical: isSmallScreen ? 5 : 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00C9FF),
                  Color(0xFF92FE9D),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C9FF).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '${service.price.toStringAsFixed(2)} جنيه',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(bool isSmallScreen) {
    return Container(
      // ... decoration code ...
      child: Row(
        children: [
          // ... Icon and SizedBox code ...
          Text(
            'الإجمالي:',
            style: TextStyle(
                // ... style code ...
                ),
          ),
          const Spacer(),
          // تم تطبيق الحل هنا
          Flexible(
            // <-- الخطوة 1: أضفنا Flexible
            child: Text(
              '${widget.order.totalPrice.toStringAsFixed(2)} جنيه مصري',
              textAlign: TextAlign
                  .right, // قد تحتاج لإضافة هذا لضمان محاذاة النص لليمين
              style: TextStyle(
                  // ... style code ...
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.4),
            Colors.white.withOpacity(0.6),
            Colors.white.withOpacity(0.4),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton(bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: double.infinity,
            height: isSmallScreen ? 55 : 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFFA500),
                  Color(0xFFFF8C00),
                  Color(0xFFFF6B35),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LeaveReviewScreen(order: widget.order),
                    ),
                  );
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isSmallScreen ? 30 : 35,
                        height: isSmallScreen ? 30 : 35,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
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
                        child: Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 18 : 22,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 10 : 12),
                      Text(
                        'قيّم الخدمة الآن',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 16 : 18,
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color.fromARGB(255, 255, 149, 0); // Orange - more vibrant
      case 'accepted':
        return const Color(0xFF007AFF); // Blue - iOS blue
      case 'completed':
        return const Color(0xFF34C759); // Green - iOS green
      case 'rejected':
        return const Color(0xFFFF3B30); // Red - iOS red
      default:
        return const Color(0xFF8E8E93); // Gray
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'accepted':
        return 'مقبول';
      case 'completed':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }
}

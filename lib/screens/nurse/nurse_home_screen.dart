import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/providers/nurse_provider.dart';
import 'package:cure_app/screens/nurse/nurse_orders_history_screen.dart';
import 'package:cure_app/screens/nurse/pending_orders_screen.dart';
import 'package:cure_app/screens/nurse/nurse_reviews_screen.dart';
import 'package:cure_app/screens/nurse/nurse_reports_screen.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NurseHomeScreen extends StatefulWidget {
  const NurseHomeScreen({super.key});

  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final nurseProvider = Provider.of<NurseProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        nurseProvider.fetchMyOrders(authProvider.currentUser!.uid);
        nurseProvider.fetchPendingOrders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, NurseProvider>(
      builder: (context, authProvider, nurseProvider, child) {
        final userProfile = authProvider.currentUserProfile;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kPrimaryColor, Colors.white],
                stops: [0.0, 0.3],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAppBar(context),
                    const SizedBox(height: 20),
                    _buildGlassCard(
                      icon: Icons.person_outline,
                      title: 'أهلاً بك، ${userProfile?.name ?? ''}!',
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text(
                              'حالة التوفر',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              userProfile?.isAvailable ?? true
                                  ? 'متاح لاستقبال الطلبات'
                                  : 'غير متاح حاليًا',
                            ),
                            value: userProfile?.isAvailable ?? true,
                            onChanged: (bool value) =>
                                authProvider.updateAvailability(value),
                            secondary: Icon(
                              userProfile?.isAvailable ?? true
                                  ? Icons.online_prediction
                                  : Icons.power_settings_new,
                              color: userProfile?.isAvailable ?? true
                                  ? Colors.green
                                  : Colors.red,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDashboardGrid(context, nurseProvider, authProvider),
                    const SizedBox(height: 24),
                    _buildQuickActions(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Provider.of<AuthProvider>(context, listen: false)
                .signOut(context),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'مركز العمليات',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    required String title,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: kPrimaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String count,
    required VoidCallback onTap,
  }) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: kPrimaryColor),
                const SizedBox(height: 12),
                Text(
                  count,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(BuildContext context, NurseProvider nurseProvider,
      AuthProvider authProvider) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildDashboardCard(
          icon: Icons.notifications_active_outlined,
          title: 'الطلبات الجديدة',
          count: nurseProvider.pendingOrdersCount.toString(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PendingOrdersScreen(),
              ),
            );
          },
        ),
        _buildDashboardCard(
          icon: Icons.directions_run_outlined,
          title: 'قيد التنفيذ',
          count: nurseProvider.acceptedOrdersCount.toString(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NurseOrdersHistoryScreen(),
              ),
            );
          },
        ),
        _buildDashboardCard(
          icon: Icons.star_half_outlined,
          title: 'متوسط التقييم',
          count: authProvider.currentUserProfile?.averageRating
                  .toStringAsFixed(1) ??
              '0.0',
          onTap: () {
            if (authProvider.currentUser != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NurseReviewsScreen(
                    nurseId: authProvider.currentUser!.uid,
                  ),
                ),
              );
            }
          },
        ),
        _buildDashboardCard(
          icon: Icons.task_alt_outlined,
          title: 'الطلبات المكتملة',
          count: nurseProvider.completedOrdersCount.toString(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NurseOrdersHistoryScreen(),
              ),
            );
          },
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .where('nurseId', isEqualTo: authProvider.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            String reportCount = '...';
            if (snapshot.connectionState == ConnectionState.active &&
                snapshot.hasData) {
              reportCount = snapshot.data!.docs.length.toString();
            } else if (snapshot.hasError) {
              reportCount = '!';
            }

            return _buildDashboardCard(
              icon: Icons.report_outlined,
              title: 'الشكاوى',
              count: reportCount,
              onTap: () {
                if (authProvider.currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NurseReportsScreen(
                        nurseId: authProvider.currentUser!.uid,
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return _buildGlassCard(
      title: 'إجراءات سريعة',
      icon: Icons.flash_on_outlined,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.history, color: kPrimaryColor),
            title: const Text('عرض سجل الطلبات الكامل'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NurseOrdersHistoryScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading:
                const Icon(Icons.account_circle_outlined, color: kPrimaryColor),
            title: const Text('تعديل الملف الشخصي'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, profileRoute);
            },
          ),
        ],
      ),
    );
  }
}

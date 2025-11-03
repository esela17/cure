// lib/screens/nurse/nurse_profile_screen.dart

import 'package:cure_app/models/user_model.dart';
import 'package:cure_app/providers/nurse_profile_provider.dart';
import 'package:cure_app/screens/all_reviews_screen.dart';
import 'package:cure_app/utils/helpers.dart';
import 'package:cure_app/widgets/empty_state.dart';
import 'package:cure_app/widgets/error_message.dart';
import 'package:cure_app/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:cure_app/providers/auth_provider.dart'; // لاستخدامه لاحقاً

class NurseProfileScreen extends StatefulWidget {
  final String nurseId;
  // ✅ إضافة حقل اختياري لعرض رصيد المستخدم الحالي
  final UserModel? currentUserProfile;

  const NurseProfileScreen(
      {super.key, required this.nurseId, this.currentUserProfile});

  @override
  State<NurseProfileScreen> createState() => _NurseProfileScreenState();
}

class _NurseProfileScreenState extends State<NurseProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      Provider.of<NurseProfileProvider>(context, listen: false)
          .fetchNurseProfileAndReviews(widget.nurseId);
    });
  }

  // ✅ دالة بناء بطاقة الرصيد الجديدة (تظهر فقط للمستخدم الحالي)
  Widget _buildPayoutBalanceCard(BuildContext context, UserModel nurse) {
    final bool isIndebted = nurse.payoutBalance < 0;
    final String sign = isIndebted ? '-' : '+';
    final Color balanceColor = isIndebted ? Colors.red.shade700 : kAccentColor;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: balanceColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: balanceColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isIndebted
                    ? Icons.account_balance_wallet_outlined
                    : Icons.monetization_on_outlined,
                color: balanceColor,
                size: 30,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIndebted
                        ? 'المديونية المستحقة للمنصة'
                        : 'رصيد مستحقاتك الصافي',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${sign} ${nurse.payoutBalance.abs().toStringAsFixed(2)} جنيه',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: balanceColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // زر للمراجعة أو التسوية (يذهب لسجل المعاملات)
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, transactionHistoryRoute);
            },
            icon: Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUserProfile = widget.currentUserProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            isCurrentUserProfile ? 'ملفي المالي' : 'الملف الشخصي للممرض',
            style: const TextStyle(color: Colors.white)),
      ),
      body: Consumer<NurseProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const LoadingIndicator();
          }
          if (provider.errorMessage != null) {
            return ErrorMessage(message: provider.errorMessage!);
          }
          if (provider.nurseProfile == null) {
            return const EmptyState(message: 'لا توجد بيانات لهذا الممرض.');
          }

          final nurse = provider.nurseProfile!;
          final reviews = provider.reviews;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // ✅ عرض بطاقة الرصيد إذا كان هو المستخدم الحالي
              if (isCurrentUserProfile)
                _buildPayoutBalanceCard(context, widget.currentUserProfile!),

              _buildProfileHeader(context, nurse),
              const Divider(height: 32),

              // 3. قسم التقييمات
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('التقييمات والمراجعات',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (reviews.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllReviewsScreen(
                              reviews: reviews,
                              nurseName: nurse.name,
                            ),
                          ),
                        );
                      },
                      child: const Text('عرض الكل'),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (reviews.isEmpty)
                const EmptyState(message: 'لا توجد تقييمات لهذا الممرض بعد.')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reviews.length > 2 ? 2 : reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(review.patientName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(formatDateTime(review.timestamp.toDate()),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            RatingBarIndicator(
                              rating: review.rating,
                              itemBuilder: (context, index) =>
                                  const Icon(Icons.star, color: Colors.amber),
                              itemCount: 5,
                              itemSize: 18.0,
                            ),
                            if (review.comment.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(review.comment,
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                )
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel nurse) {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: nurse.profileImageUrl != null
              ? NetworkImage(nurse.profileImageUrl!)
              : null,
          child: nurse.profileImageUrl == null
              ? const Icon(Icons.person, size: 60)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          nurse.name,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (nurse.specialization != null && nurse.specialization!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              nurse.specialization!,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey.shade700),
            ),
          ),
        const SizedBox(height: 16),
        RatingBarIndicator(
          rating: nurse.averageRating,
          itemBuilder: (context, index) =>
              const Icon(Icons.star, color: Colors.amber),
          itemCount: 5,
          itemSize: 25.0,
        ),
        Text(
            '${nurse.averageRating.toStringAsFixed(1)} (${nurse.ratingCount} تقييم)'),
      ],
    );
  }
}

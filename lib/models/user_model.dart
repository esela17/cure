// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? profileImageUrl;
  final bool isAvailable;
  final String? fcmToken;
  final double averageRating; // <-- إضافة موجودة
  final int ratingCount; // <-- إضافة موجودة
  final String? specialization;
  final int jobCount;
  
  // ✅ إضافة حقل الرصيد للمحاسبة
  final double payoutBalance; 

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'patient',
    this.profileImageUrl,
    this.isAvailable = true,
    this.fcmToken,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.specialization,
    this.jobCount = 0,
    // ✅ تحديث Constructor
    this.payoutBalance = 0.0, 
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'isAvailable': isAvailable,
      'fcmToken': fcmToken,
      'averageRating': averageRating, 
      'ratingCount': ratingCount, 
      'specialization': specialization,
      'jobCount': jobCount,
      // ✅ إضافة حقل الرصيد
      'payoutBalance': payoutBalance,
    };
  }

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError("Missing data for userId: ${snapshot.id}");
    }
    return UserModel(
      id: snapshot.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'patient',
      profileImageUrl: data['profileImageUrl'],
      isAvailable: data['isAvailable'] ?? true,
      fcmToken: data['fcmToken'],
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: data['ratingCount'] ?? 0,
      specialization: data['specialization'],
      jobCount: data['jobCount'] ?? 0,
      // ✅ قراءة حقل الرصيد
      payoutBalance: (data['payoutBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
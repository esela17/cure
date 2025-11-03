// lib/models/coupon_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CouponModel {
  final String id;
  final String code;
  
  // ✅ 1. حقول نظام الخصم الأصلي (لحل مشكلة undefined_getter)
  final double discountValue; 
  final bool isPercentage;    
  
  // ✅ 2. حقول نظام المحاسبة والتتبع الجديدة
  final String type; // 'percentage' or 'fixed'
  final double value; // قيمة الخصم
  final bool isActive;
  final DateTime expiryDate;
  final double minOrderAmount;
  final int maxUses;
  final int usedCount;

  CouponModel({
    required this.id,
    required this.code,
    // ✅ حقول الخصم الأصلية
    required this.discountValue,
    required this.isPercentage,
    // ✅ حقول المحاسبة الجديدة
    required this.type,
    required this.value,
    required this.isActive,
    required this.expiryDate,
    required this.minOrderAmount,
    required this.maxUses,
    required this.usedCount,
  });

  factory CouponModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;

    final couponValue = (data['value'] as num?)?.toDouble() ?? 0.0;
    final isPercent = data['type'] == 'percentage';
    
    return CouponModel(
      id: snapshot.id,
      code: data['code'] ?? '',
      
      // ✅ تعيين حقول الخصم الأصلية من حقول المحاسبة الجديدة
      discountValue: couponValue, 
      isPercentage: isPercent,    
      
      // ✅ حقول المحاسبة والتتبع الجديدة
      type: data['type'] ?? 'percentage',
      value: couponValue,
      isActive: data['isActive'] ?? false,
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      minOrderAmount: (data['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      maxUses: (data['maxUses'] as num?)?.toInt() ?? 0,
      usedCount: (data['usedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

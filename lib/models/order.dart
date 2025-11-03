// lib/models/order.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cure_app/models/service.dart';
// ✅ استيراد Constants لاستخدام ثوابت الدفع
import 'package:cure_app/utils/constants.dart'; 

class Order {
  final String id;
  final String userId;
  final String patientName;
  final List<Service> services;
  final double totalPrice; // (السعر قبل الخصم)
  final String status;
  final DateTime orderDate;
  final DateTime? appointmentDate;
  final String? notes;
  final String deliveryAddress;
  final String phoneNumber;
  final String? serviceProviderType;
  final String? nurseId;
  final String? nurseName;
  final bool isRated;
  final double? locationLat;
  final double? locationLng;

  // ✅ تقييم المستخدم
  final double? rating;
  final String? reviewText;

  // ✅ حقول الخصومات والدفع (المدمجة والمضافة)
  final String? couponCode;
  final double discountAmount;
  final double finalPrice; // (السعر بعد الخصم)
  
  // ✨ حقول نظام المحاسبة الجديدة
  final String paymentMethod; // 'cash' أو 'online'
  final double platformCommissionRate; // نسبة العمولة المخزنة وقت الطلب
  final String? transactionId; // معرف ربط الطلب بسجل /transactions
  
  // ✅ حقل سبب الرفض
  final String? rejectReason;

  Order({
    required this.id,
    required this.userId,
    required this.patientName,
    required this.services,
    required this.totalPrice,
    required this.status,
    required this.orderDate,
    this.appointmentDate,
    this.notes,
    required this.deliveryAddress,
    required this.phoneNumber,
    this.serviceProviderType,
    this.nurseId,
    this.nurseName,
    this.isRated = false,
    this.locationLat,
    this.locationLng,
    this.rating,
    this.reviewText,
    this.couponCode,
    this.discountAmount = 0.0,
    required this.finalPrice,
    this.rejectReason,
    // ✨ إضافة الحقول الجديدة
    this.paymentMethod = paymentMethodCash, // قيمة افتراضية: كاش
    this.platformCommissionRate = 0.0,
    this.transactionId,
  });

  factory Order.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError("Missing data for orderId: ${snapshot.id}");
    }

    List<Service> orderedServices = (data['services'] as List<dynamic>? ?? [])
        .map((serviceMap) => Service.fromMap(serviceMap as Map<String, dynamic>))
        .toList();

    return Order(
      id: snapshot.id,
      userId: data['userId'] ?? '',
      patientName: data['patientName'] ?? 'مستخدم غير معروف',
      services: orderedServices,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pending',
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      appointmentDate: (data['appointmentDate'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      deliveryAddress: data['deliveryAddress'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      serviceProviderType: data['serviceProviderType'],
      nurseId: data['nurseId'],
      nurseName: data['nurseName'],
      isRated: data['isRated'] ?? false,
      locationLat: (data['locationLat'] as num?)?.toDouble(),
      locationLng: (data['locationLng'] as num?)?.toDouble(),
      rating: (data['rating'] as num?)?.toDouble(),
      reviewText: data['reviewText'],

      // ✨ استخراج حقول الخصم والدفع
      couponCode: data['couponCode'],
      discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      finalPrice: (data['finalPrice'] as num?)?.toDouble() ?? 0.0,

      // ✨ قراءة حقول المحاسبة الجديدة
      paymentMethod: data['paymentMethod'] ?? paymentMethodCash,
      platformCommissionRate: (data['platformCommissionRate'] as num?)?.toDouble() ?? 0.0,
      transactionId: data['transactionId'],

      // ✨ سبب الرفض
      rejectReason: data['rejectReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'patientName': patientName,
      'services': services.map((s) => s.toMap()).toList(),
      'totalPrice': totalPrice,
      'status': status,
      'orderDate': Timestamp.fromDate(orderDate),
      'appointmentDate':
      appointmentDate != null ? Timestamp.fromDate(appointmentDate!) : null,
      'notes': notes,
      'deliveryAddress': deliveryAddress,
      'phoneNumber': phoneNumber,
      'serviceProviderType': serviceProviderType,
      'nurseId': nurseId,
      'nurseName': nurseName,
      'isRated': isRated,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'rating': rating,
      'reviewText': reviewText,

      // ✨ الحقول المالية
      'couponCode': couponCode,
      'discountAmount': discountAmount,
      'finalPrice': finalPrice,

      // ✨ حقول المحاسبة الجديدة
      'paymentMethod': paymentMethod,
      'platformCommissionRate': platformCommissionRate,
      if (transactionId != null) 'transactionId': transactionId,

      'rejectReason': rejectReason,
    };
  }
}
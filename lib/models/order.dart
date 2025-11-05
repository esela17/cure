// lib/models/order.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cure_app/models/service.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:cure_app/utils/order_statuses.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 📜 فئات مساعدة للهيكل الموسع
// ═══════════════════════════════════════════════════════════════════════════

enum CancelledBy { patient, nurse, admin, system }

class StatusHistory {
  final String status;
  final String? subStatus;
  final DateTime timestamp;
  final String? changedBy; 
  final String? reason;

  StatusHistory({
    required this.status,
    this.subStatus,
    required this.timestamp,
    this.changedBy,
    this.reason,
  });

  factory StatusHistory.fromMap(Map<String, dynamic> map) {
    return StatusHistory(
      status: map['status'] ?? 'unknown',
      subStatus: map['subStatus'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      changedBy: map['changedBy'],
      reason: map['reason'],
    );
  }

  Map<String, dynamic> toMap() => {
        'status': status,
        'subStatus': subStatus,
        'timestamp': Timestamp.fromDate(timestamp),
        'changedBy': changedBy,
        'reason': reason,
      };
}

class DisputeInfo {
  final String id;
  final String type;
  final String reportedBy;
  final String description;
  final DateTime reportedAt;
  final String status;
  final String? resolution;
  final DateTime? resolvedAt;
  final List<String> evidence;

  DisputeInfo({
    required this.id,
    required this.type,
    required this.reportedBy,
    required this.description,
    required this.reportedAt,
    this.status = 'open',
    this.resolution,
    this.resolvedAt,
    this.evidence = const [],
  });
  
  factory DisputeInfo.fromMap(Map<String, dynamic> map) {
    return DisputeInfo(
      id: map['id'] ?? '',
      type: map['type'] ?? 'general',
      reportedBy: map['reportedBy'] ?? 'patient',
      description: map['description'] ?? '',
      reportedAt: (map['reportedAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'open',
      resolution: map['resolution'],
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      evidence: List<String>.from(map['evidence'] ?? []),
    );
  }
  
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'reportedBy': reportedBy,
        'description': description,
        'reportedAt': Timestamp.fromDate(reportedAt),
        'status': status,
        'resolution': resolution,
        'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
        'evidence': evidence,
      };
}

class IssueReport {
  final String id;
  final String type;
  final String reportedBy;
  final String description;
  final DateTime reportedAt;
  final List<String> attachments;

  IssueReport({
    required this.id,
    required this.type,
    required this.reportedBy,
    required this.description,
    required this.reportedAt,
    this.attachments = const [],
  });
  
  factory IssueReport.fromMap(Map<String, dynamic> map) {
    return IssueReport(
      id: map['id'] ?? '',
      type: map['type'] ?? 'other',
      reportedBy: map['reportedBy'] ?? 'patient',
      description: map['description'] ?? '',
      reportedAt: (map['reportedAt'] as Timestamp).toDate(),
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }
  
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'reportedBy': reportedBy,
        'description': description,
        'reportedAt': Timestamp.fromDate(reportedAt),
        'attachments': attachments,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// ⭐ نموذج الطلب الموسع (Enhanced Order)
// ═══════════════════════════════════════════════════════════════════════════
class Order {
  final String id;
  final String userId;
  final String patientName;
  final List<Service> services;
  final double totalPrice; 
  
  // 📍 معلومات الحالة الموسعة
  final String status;
  final String? subStatus; 
  final List<StatusHistory> statusHistory; 
  final CancelledBy? cancelledBy; 
  final String? rejectReason; 
  final String? cancelReason; 

  // 💰 معلومات الدفع
  final String paymentMethod; 
  final String paymentStatus; 
  final double discountAmount;
  final double finalPrice; 
  final double platformCommissionRate;
  final String? transactionId;
  final bool isPaymentConfirmedByPatient; 
  final bool isPaymentConfirmedByNurse; 

  // 👨‍⚕️ معلومات الممرض
  final String? nurseId;
  final String? nurseName;
  
  // 📝 ملاحظات وتقييمات
  final String? notes;
  final bool isRated;
  final double? rating;
  final String? reviewText;

  // ⚠️ معلومات النزاعات والمشاكل
  final bool hasDispute; 
  final DisputeInfo? dispute; 
  final List<IssueReport> issues; 
  final bool requiresAdminIntervention; 

  // 🗺️ معلومات الموقع
  final String deliveryAddress; 
  final String phoneNumber;
  final String? serviceProviderType;
  final double? locationLat;
  final double? locationLng;

  // ⏱️ معلومات التوقيت والتتبع
  final DateTime orderDate;
  final DateTime? appointmentDate;
  final String? couponCode;
  
  // 🆕 حقول التتبع والتحرك والمؤقت
  final bool isNurseMovingRequested;
  final DateTime? nurseMovingRequestedAt;
  final bool isNurseMovingConfirmed;
  final DateTime? nurseMovingConfirmedAt;
  final bool patientConfirmedNurseMoving;
  final DateTime? patientConfirmedMovingAt;
  final DateTime? cancellationAvailableAt;
  final bool canPatientCancelAfterAccept;
  final DateTime? nursePaymentConfirmedAt;
  final DateTime? patientPaymentConfirmedAt;

  // 🆕 حقول تدفق الدفع النقدي المحسن
  final bool isCashPaymentRequested;
  final DateTime? cashPaymentRequestedAt;
  final bool isCashPaymentReceived;
  final DateTime? cashPaymentReceivedAt;
  final bool isCashHandoverConfirmed;
  final DateTime? cashHandoverConfirmedAt;
  final String? cashPaymentNotes;

  // 🆕🆕🆕 حقول تأكيد وصول الممرض والإبلاغ
  final bool? isNurseArrivalConfirmedByPatient;
  final DateTime? nurseArrivalConfirmedAt;
  final bool? nurseNotArrivedReported;
  final DateTime? nurseNotArrivedReportedAt;
  final bool? wrongNurseReported;
  final DateTime? wrongNurseReportedAt;

  Order({
    required this.id,
    required this.userId,
    required this.patientName,
    required this.services,
    required this.totalPrice,
    required this.status,
    required this.orderDate,
    required this.deliveryAddress,
    required this.phoneNumber,
    required this.finalPrice,
    
    // 📍 الحالة الموسعة
    this.subStatus,
    this.statusHistory = const [],
    this.cancelledBy,
    this.rejectReason, 
    this.cancelReason,

    // 💰 الدفع
    this.paymentMethod = paymentMethodCash,
    this.paymentStatus = 'pending_payment',
    this.discountAmount = 0.0,
    this.platformCommissionRate = 0.0,
    this.transactionId,
    this.isPaymentConfirmedByPatient = false,
    this.isPaymentConfirmedByNurse = false,

    // 👨‍⚕️ الممرض
    this.nurseId,
    this.nurseName,

    // 📝 عامة
    this.appointmentDate,
    this.notes,
    this.serviceProviderType,
    this.isRated = false,
    this.locationLat,
    this.locationLng,
    this.rating,
    this.reviewText,
    this.couponCode,

    // ⚠️ المشاكل والنزاعات
    this.hasDispute = false,
    this.dispute,
    this.issues = const [],
    this.requiresAdminIntervention = false,

    // 🆕 حقول التتبع والتحرك والمؤقت
    this.isNurseMovingRequested = false,
    this.nurseMovingRequestedAt,
    this.isNurseMovingConfirmed = false,
    this.nurseMovingConfirmedAt,
    this.patientConfirmedNurseMoving = false,
    this.patientConfirmedMovingAt,
    this.cancellationAvailableAt,
    this.canPatientCancelAfterAccept = false,
    this.nursePaymentConfirmedAt,
    this.patientPaymentConfirmedAt,

    // 🆕 حقول تدفق الدفع النقدي المحسن
    this.isCashPaymentRequested = false,
    this.cashPaymentRequestedAt,
    this.isCashPaymentReceived = false,
    this.cashPaymentReceivedAt,
    this.isCashHandoverConfirmed = false,
    this.cashHandoverConfirmedAt,
    this.cashPaymentNotes,

    // 🆕🆕🆕 حقول تأكيد وصول الممرض والإبلاغ
    this.isNurseArrivalConfirmedByPatient,
    this.nurseArrivalConfirmedAt,
    this.nurseNotArrivedReported,
    this.nurseNotArrivedReportedAt,
    this.wrongNurseReported,
    this.wrongNurseReportedAt,
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

    List<StatusHistory> history = (data['statusHistory'] as List<dynamic>? ?? [])
        .map((map) => StatusHistory.fromMap(map as Map<String, dynamic>))
        .toList();
    
    DisputeInfo? disputeInfo;
    if (data['dispute'] != null) {
      disputeInfo = DisputeInfo.fromMap(data['dispute'] as Map<String, dynamic>);
    }

    return Order(
      id: snapshot.id,
      userId: data['userId'] ?? '',
      patientName: data['patientName'] ?? 'مستخدم غير معروف',
      services: orderedServices,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pending',
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      deliveryAddress: data['deliveryAddress'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      finalPrice: (data['finalPrice'] as num?)?.toDouble() ?? 0.0,

      // 📍 الحالة الموسعة
      subStatus: data['subStatus'],
      statusHistory: history,
      cancelledBy: data['cancelledBy'] != null 
          ? CancelledBy.values.firstWhere((e) => e.toString() == 'CancelledBy.${data['cancelledBy']}', orElse: () => CancelledBy.patient) 
          : null,
      rejectReason: data['rejectReason'], 
      cancelReason: data['cancelReason'],

      // 💰 الدفع
      paymentMethod: data['paymentMethod'] ?? paymentMethodCash,
      paymentStatus: data['paymentStatus'] ?? 'pending_payment',
      discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      platformCommissionRate: (data['platformCommissionRate'] as num?)?.toDouble() ?? 0.0,
      transactionId: data['transactionId'],
      isPaymentConfirmedByPatient: data['isPaymentConfirmedByPatient'] ?? false, 
      isPaymentConfirmedByNurse: data['isPaymentConfirmedByNurse'] ?? false,

      // 👨‍⚕️ الممرض
      nurseId: data['nurseId'],
      nurseName: data['nurseName'],

      // 📝 عامة
      appointmentDate: (data['appointmentDate'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      serviceProviderType: data['serviceProviderType'],
      isRated: data['isRated'] ?? false,
      locationLat: (data['locationLat'] as num?)?.toDouble(),
      locationLng: (data['locationLng'] as num?)?.toDouble(),
      rating: (data['rating'] as num?)?.toDouble(),
      reviewText: data['reviewText'],
      couponCode: data['couponCode'],

      // ⚠️ المشاكل والنزاعات
      hasDispute: data['hasDispute'] ?? false,
      dispute: disputeInfo,
      issues: (data['issues'] as List<dynamic>? ?? [])
          .map((map) => IssueReport.fromMap(map as Map<String, dynamic>))
          .toList(),
      requiresAdminIntervention: data['requiresAdminIntervention'] ?? false,
      
      // 🆕 قراءة حقول التتبع الجديدة
      isNurseMovingRequested: data['isNurseMovingRequested'] ?? false,
      nurseMovingRequestedAt: (data['nurseMovingRequestedAt'] as Timestamp?)?.toDate(),
      isNurseMovingConfirmed: data['isNurseMovingConfirmed'] ?? false,
      nurseMovingConfirmedAt: (data['nurseMovingConfirmedAt'] as Timestamp?)?.toDate(),
      patientConfirmedNurseMoving: data['patientConfirmedNurseMoving'] ?? false,
      patientConfirmedMovingAt: (data['patientConfirmedMovingAt'] as Timestamp?)?.toDate(),
      cancellationAvailableAt: (data['cancellationAvailableAt'] as Timestamp?)?.toDate(),
      canPatientCancelAfterAccept: data['canPatientCancelAfterAccept'] ?? false,
      nursePaymentConfirmedAt: (data['nursePaymentConfirmedAt'] as Timestamp?)?.toDate(),
      patientPaymentConfirmedAt: (data['patientPaymentConfirmedAt'] as Timestamp?)?.toDate(),

      // 🆕 قراءة حقول تدفق الدفع النقدي المحسن
      isCashPaymentRequested: data['isCashPaymentRequested'] ?? false,
      cashPaymentRequestedAt: (data['cashPaymentRequestedAt'] as Timestamp?)?.toDate(),
      isCashPaymentReceived: data['isCashPaymentReceived'] ?? false,
      cashPaymentReceivedAt: (data['cashPaymentReceivedAt'] as Timestamp?)?.toDate(),
      isCashHandoverConfirmed: data['isCashHandoverConfirmed'] ?? false,
      cashHandoverConfirmedAt: (data['cashHandoverConfirmedAt'] as Timestamp?)?.toDate(),
      cashPaymentNotes: data['cashPaymentNotes'],

      // 🆕🆕🆕 قراءة حقول تأكيد وصول الممرض والإبلاغ
      isNurseArrivalConfirmedByPatient: data['isNurseArrivalConfirmedByPatient'],
      nurseArrivalConfirmedAt: (data['nurseArrivalConfirmedAt'] as Timestamp?)?.toDate(),
      nurseNotArrivedReported: data['nurseNotArrivedReported'],
      nurseNotArrivedReportedAt: (data['nurseNotArrivedReportedAt'] as Timestamp?)?.toDate(),
      wrongNurseReported: data['wrongNurseReported'],
      wrongNurseReportedAt: (data['wrongNurseReportedAt'] as Timestamp?)?.toDate(),
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
      'deliveryAddress': deliveryAddress,
      'phoneNumber': phoneNumber,
      'finalPrice': finalPrice,
      
      // 📍 الحالة الموسعة
      'subStatus': subStatus,
      'statusHistory': statusHistory.map((h) => h.toMap()).toList(),
      'cancelledBy': cancelledBy?.toString().split('.').last,
      'rejectReason': rejectReason, 
      'cancelReason': cancelReason,

      // 💰 الدفع
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'discountAmount': discountAmount,
      'platformCommissionRate': platformCommissionRate,
      'transactionId': transactionId,
      'isPaymentConfirmedByPatient': isPaymentConfirmedByPatient, 
      'isPaymentConfirmedByNurse': isPaymentConfirmedByNurse,

      // 👨‍⚕️ الممرض
      'nurseId': nurseId,
      'nurseName': nurseName,

      // 📝 عامة
      'appointmentDate': appointmentDate != null ? Timestamp.fromDate(appointmentDate!) : null,
      'notes': notes,
      'serviceProviderType': serviceProviderType,
      'isRated': isRated,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'rating': rating,
      'reviewText': reviewText,
      'couponCode': couponCode,

      // ⚠️ المشاكل والنزاعات
      'hasDispute': hasDispute,
      'dispute': dispute?.toMap(),
      'issues': issues.map((i) => i.toMap()).toList(),
      'requiresAdminIntervention': requiresAdminIntervention,
      
      // 🆕 كتابة حقول التتبع الجديدة
      'isNurseMovingRequested': isNurseMovingRequested,
      'nurseMovingRequestedAt': nurseMovingRequestedAt != null ? Timestamp.fromDate(nurseMovingRequestedAt!) : null,
      'isNurseMovingConfirmed': isNurseMovingConfirmed,
      'nurseMovingConfirmedAt': nurseMovingConfirmedAt != null ? Timestamp.fromDate(nurseMovingConfirmedAt!) : null,
      'patientConfirmedNurseMoving': patientConfirmedNurseMoving,
      'patientConfirmedMovingAt': patientConfirmedMovingAt != null ? Timestamp.fromDate(patientConfirmedMovingAt!) : null,
      'cancellationAvailableAt': cancellationAvailableAt != null ? Timestamp.fromDate(cancellationAvailableAt!) : null,
      'canPatientCancelAfterAccept': canPatientCancelAfterAccept,
      'nursePaymentConfirmedAt': nursePaymentConfirmedAt != null ? Timestamp.fromDate(nursePaymentConfirmedAt!) : null,
      'patientPaymentConfirmedAt': patientPaymentConfirmedAt != null ? Timestamp.fromDate(patientPaymentConfirmedAt!) : null,

      // 🆕 كتابة حقول تدفق الدفع النقدي المحسن
      'isCashPaymentRequested': isCashPaymentRequested,
      'cashPaymentRequestedAt': cashPaymentRequestedAt != null ? Timestamp.fromDate(cashPaymentRequestedAt!) : null,
      'isCashPaymentReceived': isCashPaymentReceived,
      'cashPaymentReceivedAt': cashPaymentReceivedAt != null ? Timestamp.fromDate(cashPaymentReceivedAt!) : null,
      'isCashHandoverConfirmed': isCashHandoverConfirmed,
      'cashHandoverConfirmedAt': cashHandoverConfirmedAt != null ? Timestamp.fromDate(cashHandoverConfirmedAt!) : null,
      'cashPaymentNotes': cashPaymentNotes,

      // 🆕🆕🆕 كتابة حقول تأكيد وصول الممرض والإبلاغ
      'isNurseArrivalConfirmedByPatient': isNurseArrivalConfirmedByPatient,
      'nurseArrivalConfirmedAt': nurseArrivalConfirmedAt != null ? Timestamp.fromDate(nurseArrivalConfirmedAt!) : null,
      'nurseNotArrivedReported': nurseNotArrivedReported,
      'nurseNotArrivedReportedAt': nurseNotArrivedReportedAt != null ? Timestamp.fromDate(nurseNotArrivedReportedAt!) : null,
      'wrongNurseReported': wrongNurseReported,
      'wrongNurseReportedAt': wrongNurseReportedAt != null ? Timestamp.fromDate(wrongNurseReportedAt!) : null,
    };
  }

  Order copyWith({
    String? id,
    String? userId,
    String? patientName,
    List<Service>? services,
    double? totalPrice,
    String? status,
    String? subStatus,
    List<StatusHistory>? statusHistory,
    CancelledBy? cancelledBy,
    String? rejectReason,
    String? cancelReason,
    String? paymentMethod,
    String? paymentStatus,
    double? discountAmount,
    double? finalPrice,
    double? platformCommissionRate,
    String? transactionId,
    bool? isPaymentConfirmedByPatient,
    bool? isPaymentConfirmedByNurse,
    String? nurseId,
    String? nurseName,
    String? notes,
    bool? isRated,
    double? rating,
    String? reviewText,
    bool? hasDispute,
    DisputeInfo? dispute,
    List<IssueReport>? issues,
    bool? requiresAdminIntervention,
    String? deliveryAddress,
    String? phoneNumber,
    String? serviceProviderType,
    double? locationLat,
    double? locationLng,
    DateTime? orderDate,
    DateTime? appointmentDate,
    String? couponCode,
    bool? isNurseMovingRequested,
    DateTime? nurseMovingRequestedAt,
    bool? isNurseMovingConfirmed,
    DateTime? nurseMovingConfirmedAt,
    bool? patientConfirmedNurseMoving,
    DateTime? patientConfirmedMovingAt,
    DateTime? cancellationAvailableAt,
    bool? canPatientCancelAfterAccept,
    DateTime? nursePaymentConfirmedAt,
    DateTime? patientPaymentConfirmedAt,
    bool? isCashPaymentRequested,
    DateTime? cashPaymentRequestedAt,
    bool? isCashPaymentReceived,
    DateTime? cashPaymentReceivedAt,
    bool? isCashHandoverConfirmed,
    DateTime? cashHandoverConfirmedAt,
    String? cashPaymentNotes,
    bool? isNurseArrivalConfirmedByPatient,
    DateTime? nurseArrivalConfirmedAt,
    bool? nurseNotArrivedReported,
    DateTime? nurseNotArrivedReportedAt,
    bool? wrongNurseReported,
    DateTime? wrongNurseReportedAt,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      patientName: patientName ?? this.patientName,
      services: services ?? this.services,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      orderDate: orderDate ?? this.orderDate,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      finalPrice: finalPrice ?? this.finalPrice,
      subStatus: subStatus ?? this.subStatus,
      statusHistory: statusHistory ?? this.statusHistory,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      rejectReason: rejectReason ?? this.rejectReason,
      cancelReason: cancelReason ?? this.cancelReason,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      discountAmount: discountAmount ?? this.discountAmount,
      platformCommissionRate: platformCommissionRate ?? this.platformCommissionRate,
      transactionId: transactionId ?? this.transactionId,
      isPaymentConfirmedByPatient: isPaymentConfirmedByPatient ?? this.isPaymentConfirmedByPatient,
      isPaymentConfirmedByNurse: isPaymentConfirmedByNurse ?? this.isPaymentConfirmedByNurse,
      nurseId: nurseId ?? this.nurseId,
      nurseName: nurseName ?? this.nurseName,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      notes: notes ?? this.notes,
      serviceProviderType: serviceProviderType ?? this.serviceProviderType,
      isRated: isRated ?? this.isRated,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      couponCode: couponCode ?? this.couponCode,
      hasDispute: hasDispute ?? this.hasDispute,
      dispute: dispute ?? this.dispute,
      issues: issues ?? this.issues,
      requiresAdminIntervention: requiresAdminIntervention ?? this.requiresAdminIntervention,
      isNurseMovingRequested: isNurseMovingRequested ?? this.isNurseMovingRequested,
      nurseMovingRequestedAt: nurseMovingRequestedAt ?? this.nurseMovingRequestedAt,
      isNurseMovingConfirmed: isNurseMovingConfirmed ?? this.isNurseMovingConfirmed,
      nurseMovingConfirmedAt: nurseMovingConfirmedAt ?? this.nurseMovingConfirmedAt,
      patientConfirmedNurseMoving: patientConfirmedNurseMoving ?? this.patientConfirmedNurseMoving,
      patientConfirmedMovingAt: patientConfirmedMovingAt ?? this.patientConfirmedMovingAt,
      cancellationAvailableAt: cancellationAvailableAt ?? this.cancellationAvailableAt,
      canPatientCancelAfterAccept: canPatientCancelAfterAccept ?? this.canPatientCancelAfterAccept,
      nursePaymentConfirmedAt: nursePaymentConfirmedAt ?? this.nursePaymentConfirmedAt,
      patientPaymentConfirmedAt: patientPaymentConfirmedAt ?? this.patientPaymentConfirmedAt,
      isCashPaymentRequested: isCashPaymentRequested ?? this.isCashPaymentRequested,
      cashPaymentRequestedAt: cashPaymentRequestedAt ?? this.cashPaymentRequestedAt,
      isCashPaymentReceived: isCashPaymentReceived ?? this.isCashPaymentReceived,
      cashPaymentReceivedAt: cashPaymentReceivedAt ?? this.cashPaymentReceivedAt,
      isCashHandoverConfirmed: isCashHandoverConfirmed ?? this.isCashHandoverConfirmed,
      cashHandoverConfirmedAt: cashHandoverConfirmedAt ?? this.cashHandoverConfirmedAt,
      cashPaymentNotes: cashPaymentNotes ?? this.cashPaymentNotes,
      isNurseArrivalConfirmedByPatient: isNurseArrivalConfirmedByPatient ?? this.isNurseArrivalConfirmedByPatient,
      nurseArrivalConfirmedAt: nurseArrivalConfirmedAt ?? this.nurseArrivalConfirmedAt,
      nurseNotArrivedReported: nurseNotArrivedReported ?? this.nurseNotArrivedReported,
      nurseNotArrivedReportedAt: nurseNotArrivedReportedAt ?? this.nurseNotArrivedReportedAt,
      wrongNurseReported: wrongNurseReported ?? this.wrongNurseReported,
      wrongNurseReportedAt: wrongNurseReportedAt ?? this.wrongNurseReportedAt,
    );
  }

  // 🆕 دوال مساعدة للدفع النقدي
  bool get isCashPaymentPending => 
      paymentMethod == paymentMethodCash && 
      status == 'arrived' && 
      !isPaymentConfirmedByNurse;

  bool get isCashPaymentInProgress => 
      paymentMethod == paymentMethodCash && 
      status == 'arrived' && 
      isCashPaymentRequested && 
      !isCashPaymentReceived;

  bool get isCashPaymentReadyForConfirmation => 
      paymentMethod == paymentMethodCash && 
      status == 'arrived' && 
      isCashPaymentRequested && 
      (isPaymentConfirmedByPatient || isCashPaymentReceived);

  bool get isCashPaymentCompleted => 
      paymentMethod == paymentMethodCash && 
      isPaymentConfirmedByNurse && 
      isCashPaymentReceived;

  // 🆕 دوال لحساب الأرباح
  double get commissionAmount => finalPrice * (platformCommissionRate / 100);
  double get nurseEarnings => finalPrice - commissionAmount;

  // 🆕 دوال للتحقق من الحالة
  bool get canRequestCashPayment => 
      paymentMethod == paymentMethodCash && 
      status == 'arrived' && 
      !isCashPaymentRequested;

  bool get canConfirmCashReceipt => 
      paymentMethod == paymentMethodCash && 
      status == 'arrived' && 
      isCashPaymentRequested && 
      !isPaymentConfirmedByNurse;

  // 🆕 دوال للحصول على نص الحالة
  String get cashPaymentStatusText {
    if (paymentMethod != paymentMethodCash) return 'غير نقدي';
    
    if (isCashPaymentCompleted) return 'تم استلام الدفع النقدي';
    if (isPaymentConfirmedByNurse) return 'بانتظار تأكيد النظام';
    if (isCashPaymentReceived) return 'تم تسليم المبلغ - بانتظار التأكيد';
    if (isCashPaymentRequested) return 'بانتظار تسليم المريض للمبلغ';
    if (status == 'arrived') return 'جاهز لطلب الدفع النقدي';
    
    return 'غير جاهز للدفع النقدي';
  }

  // 🆕 دالة للتحقق من إمكانية إكمال الطلب
  bool get canCompleteOrder {
    if (paymentMethod == paymentMethodCash) {
      return isPaymentConfirmedByNurse && isCashPaymentReceived;
    } else {
      return status == 'arrived';
    }
  }

  // 🆕🆕🆕 دوال تأكيد وصول الممرض
  bool get canConfirmNurseArrival => 
      status == OrderStatus.arrived && 
      isNurseArrivalConfirmedByPatient != true;

  bool get shouldShowArrivalButtons => 
      status == OrderStatus.arrived && 
      isNurseArrivalConfirmedByPatient != true;
}
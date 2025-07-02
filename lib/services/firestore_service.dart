// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart' as firestore_package;
import 'package:cure_app/models/ad_banner.dart';
import 'package:cure_app/models/category_shortcut.dart';
import 'package:cure_app/models/order.dart';
import 'package:cure_app/models/review_model.dart';
import 'package:cure_app/models/service.dart';
import 'package:cure_app/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreService {
  final firestore_package.FirebaseFirestore _db =
      firestore_package.FirebaseFirestore.instance;

  // --- USER-RELATED FUNCTIONS ---

  Future<void> addUser(UserModel user) async {
    await _db
        .collection('users')
        .doc(user.id)
        .withConverter<UserModel>(
          fromFirestore: UserModel.fromFirestore,
          toFirestore: (UserModel user, options) => user.toFirestore(),
        )
        .set(user);
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .withConverter<UserModel>(
          fromFirestore: UserModel.fromFirestore,
          toFirestore: (user, options) => user.toFirestore(),
        )
        .get();
    return doc.data();
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> incrementNurseJobCount(String nurseId) async {
    final nurseRef = _db.collection('users').doc(nurseId);
    await nurseRef.update({
      'jobCount': firestore_package.FieldValue.increment(1),
    });
  }

  // --- SERVICE-RELATED FUNCTIONS ---

  Stream<List<Service>> getServices() {
    return _db
        .collection('services')
        .withConverter<Service>(
          fromFirestore: Service.fromFirestore,
          toFirestore: (Service service, options) => service.toFirestore(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // --- ORDER-RELATED FUNCTIONS ---

  Future<firestore_package.DocumentReference> addOrder(Order order) async {
    // ✅✅✅ هذا هو السطر الذي تم تعديله - الحل النهائي للمشكلة ✅✅✅
    final docRef = await _db.collection('requests').add({
      ...order.toFirestore(),
      if (order.locationLat != null) 'locationLat': order.locationLat,
      if (order.locationLng != null) 'locationLng': order.locationLng,
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeOrderId', docRef.id);

    return docRef;
  }

  Future<void> updateOrderStatus(
      String orderId, Map<String, dynamic> dataToUpdate) async {
    // تم تعديل اسم المجموعة هنا أيضاً ليتوافق مع باقي أجزاء التطبيق
    await _db.collection('requests').doc(orderId).update(dataToUpdate);

    if (dataToUpdate.containsKey('status') &&
        (dataToUpdate['status'] == 'completed' ||
            dataToUpdate['status'] == 'canceled')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('activeOrderId');
    }
  }

  Stream<Order> getOrderStream(String orderId) {
    return _db
        .collection('requests') // تعديل لتوحيد الاسم
        .doc(orderId)
        .withConverter<Order>(
          fromFirestore: Order.fromFirestore,
          toFirestore: (Order order, options) => order.toFirestore(),
        )
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception("Order with ID $orderId not found!");
      }
      return snapshot.data()!;
    });
  }

  Stream<List<Order>> getUserOrders(String userId) {
    return _db
        .collection('requests') // تعديل لتوحيد الاسم
        .where('userId', isEqualTo: userId)
        .orderBy('orderDate', descending: true)
        .withConverter<Order>(
          fromFirestore: Order.fromFirestore,
          toFirestore: (Order order, options) => order.toFirestore(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Order>> getPendingOrders() {
    return _db
        .collection('requests') // تعديل لتوحيد الاسم
        .where('status', isEqualTo: 'pending')
        .orderBy('orderDate', descending: true)
        .withConverter<Order>(
          fromFirestore: Order.fromFirestore,
          toFirestore: (Order order, options) => order.toFirestore(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Order>> getOrdersForNurse(String nurseId) {
    return _db
        .collection('requests') // تعديل لتوحيد الاسم
        .where('nurseId', isEqualTo: nurseId)
        .orderBy('orderDate', descending: true)
        .withConverter<Order>(
          fromFirestore: Order.fromFirestore,
          toFirestore: (Order order, options) => order.toFirestore(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // --- ADVERTISEMENT & CATEGORY FUNCTIONS ---

  Stream<List<AdBanner>> getAdvertisements() {
    return _db
        .collection('advertisements')
        .withConverter<AdBanner>(
          fromFirestore: (snapshot, _) => AdBanner.fromFirestore(snapshot),
          toFirestore: (ad, _) => {}, // Not needed for reading
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<CategoryShortcut>> getCategoryShortcuts() {
    return _db
        .collection('categories')
        .orderBy('index', descending: false)
        .withConverter<CategoryShortcut>(
          fromFirestore: (snapshot, _) =>
              CategoryShortcut.fromFirestore(snapshot),
          toFirestore: (category, _) => {}, // Not needed for reading
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // --- REVIEW-RELATED FUNCTIONS ---

  Future<void> submitReview({
    required String orderId,
    required String nurseId,
    required double rating,
    required String reviewText,
    required String patientName,
  }) async {
    final nurseRef = _db.collection('users').doc(nurseId);
    final orderRef =
        _db.collection('requests').doc(orderId); // تعديل لتوحيد الاسم
    final reviewRef = nurseRef.collection('reviews').doc();

    return _db.runTransaction((transaction) async {
      final nurseDoc = await transaction.get(nurseRef);
      if (!nurseDoc.exists) {
        throw Exception("Nurse not found!");
      }

      final currentRatingCount = nurseDoc.data()?['ratingCount'] ?? 0;
      final currentAverageRating =
          (nurseDoc.data()?['averageRating'] as num?)?.toDouble() ?? 0.0;

      final newAverageRating =
          ((currentAverageRating * currentRatingCount) + rating) /
              (currentRatingCount + 1);
      final newRatingCount = currentRatingCount + 1;

      transaction.set(reviewRef, {
        'rating': rating,
        'comment': reviewText,
        'patientName': patientName,
        'timestamp': firestore_package.FieldValue.serverTimestamp(),
      });

      transaction.update(nurseRef, {
        'ratingCount': newRatingCount,
        'averageRating': newAverageRating,
      });

      transaction.update(orderRef, {'isRated': true});
    });
  }

  Future<List<ReviewModel>> getReviewsForNurse(String nurseId) async {
    final reviewsSnapshot = await _db
        .collection('users')
        .doc(nurseId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .get();

    return reviewsSnapshot.docs
        .map((doc) => ReviewModel.fromFirestore(doc))
        .toList();
  }
}

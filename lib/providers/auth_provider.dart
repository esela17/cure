// lib/providers/auth_provider.dart

import 'dart:io';
import 'package:cure_app/models/user_model.dart';
import 'package:cure_app/services/auth_service.dart';
import 'package:cure_app/services/firestore_service.dart';
import 'package:cure_app/services/navigation_service.dart';
import 'package:cure_app/services/notification_service.dart';
import 'package:cure_app/services/storage_service.dart';
import 'package:cure_app/widgets/chat_overlay_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();

  User? _currentUser;
  UserModel? _currentUserProfile;
  bool _isLoading = false;
  String? _errorMessage;

  bool _initialized = false;
  bool get initialized => _initialized;

  AuthProvider(AuthService authService) {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  User? get currentUser => _currentUser;
  UserModel? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _onAuthStateChanged(User? user) async {
    _currentUser = user;
    final context = NavigationService.navigatorKey.currentContext;

    if (user != null) {
      await fetchCurrentUserProfile();
    } else {
      _currentUserProfile = null;
      if (context != null) {
        ChatOverlayManager.hide();
      }
    }

    if (!_initialized) {
      _initialized = true;
    }
    notifyListeners();
  }

  Future<void> fetchCurrentUserProfile() async {
    if (_currentUser != null) {
      // لا تقم بإظهار التحميل هنا لتجنب وميض الواجهة
      try {
        final userProfile = await _firestoreService.getUser(_currentUser!.uid);
        if (userProfile != null) {
          _currentUserProfile = userProfile;
          _errorMessage = null;
          await _initNotificationsForUser(userProfile);
        } else {
          _errorMessage = "لم يتم العثور على ملف المستخدم.";
        }
      } catch (e) {
        _errorMessage = "حدث خطأ أثناء تحميل البيانات: $e";
      }
      notifyListeners();
    }
  }

  Future<void> _initNotificationsForUser(UserModel userProfile) async {
    try {
      await _notificationService.requestPermission();
      final token = await _notificationService.getFcmToken();
      if (token != null && userProfile.fcmToken != token) {
        await _firestoreService.updateUser(userProfile.id, {'fcmToken': token});
      }
      if (userProfile.role == 'nurse') {
        if (userProfile.isAvailable) {
          await _firebaseMessaging.subscribeToTopic('nurses');
        } else {
          await _firebaseMessaging.unsubscribeFromTopic('nurses');
        }
      }
    } catch (e) {
      _errorMessage = "فشل تهيئة الإشعارات.";
    }
  }

  Future<void> updateAvailability(bool available) async {
    if (_currentUser == null) return;
    try {
      await _firestoreService.updateUser(
        _currentUser!.uid,
        {'isAvailable': available},
      );
      if (currentUserProfile?.role == 'nurse') {
        if (available) {
          await _firebaseMessaging.subscribeToTopic('nurses');
        } else {
          await _firebaseMessaging.unsubscribeFromTopic('nurses');
        }
      }
      await fetchCurrentUserProfile();
    } catch (e) {
      _errorMessage = "فشل تحديث التوفر: $e";
      notifyListeners();
    }
  }

  Future<void> signOut(BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (currentUserProfile?.role == 'nurse') {
        await _firebaseMessaging.unsubscribeFromTopic('nurses');
      }
      await GoogleSignIn().signOut();
      await _firebaseAuth.signOut();

      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    } catch (e) {
      _errorMessage = 'فشل في عملية تسجيل الخروج.';
    } finally {
      _isLoading = false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _translateFirebaseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅✨ الدالة الأولى المُعدلة (أبسط وأكثر تركيزًا)
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    if (_currentUser == null) {
      _errorMessage = "المستخدم غير مسجل للدخول.";
      return false;
    }
    try {
      await _firestoreService.updateUser(_currentUser!.uid, data);
      await fetchCurrentUserProfile();
      return true;
    } catch (e) {
      _errorMessage = "فشل تحديث البيانات: $e";
      return false;
    }
  }

  // ✅✨ الدالة الثانية المُعدلة (تتحكم بشكل كامل في عملية الرفع)
  Future<void> pickAndUploadProfileImage() async {
    if (_currentUser == null) return;

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      File imageFile = File(pickedFile.path);
      String downloadUrl = await _storageService.uploadImage(
          imageFile, 'profile_images/${_currentUser!.uid}');

      final success = await updateUserProfile({'profileImageUrl': downloadUrl});

      if (!success) {
        _errorMessage ??= 'فشل تحديث رابط الصورة في الملف الشخصي.';
      }
    } catch (e) {
      _errorMessage = 'فشل رفع الصورة: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(
      String email, String password, BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      _errorMessage = _translateFirebaseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required BuildContext context,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      User? newUser = userCredential.user;
      if (newUser != null) {
        UserModel userModel = UserModel(
          id: newUser.uid,
          name: name,
          email: email,
          phone: phone,
        );
        await _firestoreService.addUser(userModel);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _translateFirebaseError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _errorMessage = 'تم إلغاء تسجيل الدخول عبر Google.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user != null) {
        final existingUser = await _firestoreService.getUser(user.uid);
        if (existingUser == null) {
          _errorMessage = "هذا الحساب غير مسجل لدينا. يرجى استخدام حساب آخر.";
          await _firebaseAuth.signOut();
          await GoogleSignIn().signOut();
          _isLoading = false;
          notifyListeners();
          return false;
        }
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _translateFirebaseError(e);
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تسجيل الدخول عبر Google.';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  String _translateFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'لا يوجد مستخدم بهذا البريد.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد مستخدم بالفعل.';
      case 'invalid-email':
        return 'بريد إلكتروني غير صالح.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة.';
      default:
        return e.message ?? 'حدث خطأ غير معروف.';
    }
  }
}

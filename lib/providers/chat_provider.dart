// lib/providers/chat_provider.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cure_app/models/chat_message.dart';
import 'package:cure_app/models/user_model.dart';
import 'package:cure_app/providers/active_order_provider.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/services/firestore_service.dart'; // استيراد جديد
import 'package:flutter/material.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService; // ✅ استيراد جديد

  AuthProvider _authProvider;
  ActiveOrderProvider _activeOrderProvider;

  StreamSubscription? _messagesSubscription;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // --- ✅ متغيرات جديدة لحفظ بيانات الطرف الآخر ---
  String? _chatId;
  String? _chatPartnerId;
  String? partnerName;
  String? partnerImageUrl;
  bool _isSupportChat = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  ChatProvider(
      this._authProvider, this._activeOrderProvider, this._firestoreService) {
    determineChatContext();
  }

  void update(AuthProvider newAuth, ActiveOrderProvider newActiveOrder) {
    bool needsUpdate =
        (_authProvider.currentUser?.uid != newAuth.currentUser?.uid) ||
            (_activeOrderProvider.activeOrder?.id !=
                newActiveOrder.activeOrder?.id);

    _authProvider = newAuth;
    _activeOrderProvider = newActiveOrder;

    if (needsUpdate) {
      determineChatContext();
    }
  }

  Future<void> determineChatContext() async {
    final currentUser = _authProvider.currentUser;
    final activeOrder = _activeOrderProvider.activeOrder;

    if (currentUser == null) {
      _messagesSubscription?.cancel();
      return;
    }

    String newPartnerId;
    String newChatId;
    bool newIsSupportChat = false;

    // --- ✅ منطق محدّث لجلب بيانات الطرف الآخر ---
    if (activeOrder != null &&
        activeOrder.nurseId != null &&
        activeOrder.nurseId!.isNotEmpty) {
      // حالة وجود طلب نشط: المحادثة مع الممرض
      newPartnerId = activeOrder.nurseId!;
      newChatId = _createP2PChatId(currentUser.uid, newPartnerId);
      newIsSupportChat = false;

      // جلب بيانات الممرض
      UserModel? nurseProfile = await _firestoreService.getUser(newPartnerId);
      partnerName = nurseProfile?.name ?? 'ممرض';
      partnerImageUrl = nurseProfile?.profileImageUrl;
    } else {
      // حالة عدم وجود طلب: المحادثة مع الدعم الفني
      newPartnerId = 'support_team';
      newChatId = currentUser.uid;
      newIsSupportChat = true;
      partnerName = 'الدعم الفني';
      partnerImageUrl = null; // أو يمكنك وضع صورة شعار الدعم
    }

    if (newChatId == _chatId) return;

    _chatPartnerId = newPartnerId;
    _chatId = newChatId;
    _isSupportChat = newIsSupportChat;

    print(
        '🔄 تم تحديد سياق المحادثة: Chat ID = $_chatId, Partner = $partnerName');

    if (!_isSupportChat) {
      await _ensureChatDocumentExists();
    }

    _fetchMessages();
    notifyListeners(); // لإعلام الواجهة بالاسم الجديد
  }

  Future<void> _ensureChatDocumentExists() async {
    if (_chatId == null ||
        _authProvider.currentUser == null ||
        _chatPartnerId == null) {
      return;
    }

    final chatDocRef = _firestore.collection('chats').doc(_chatId);
    final currentUserProfile = _authProvider.currentUserProfile;
    final partnerProfile = await _firestoreService.getUser(_chatPartnerId!);

    // حفظ كل البيانات اللازمة في مستند المحادثة
    await chatDocRef.set({
      'participants': [_authProvider.currentUser!.uid, _chatPartnerId],
      'participantNames': {
        currentUserProfile!.id: currentUserProfile.name,
        if (partnerProfile != null) partnerProfile.id: partnerProfile.name,
      },
      'participantImages': {
        currentUserProfile.id: currentUserProfile.profileImageUrl,
        if (partnerProfile != null)
          partnerProfile.id: partnerProfile.profileImageUrl,
      }
    }, SetOptions(merge: true));
    print('✅ تم التأكد من وجود مستند المحادثة: $_chatId');
  }

  String _createP2PChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  void _fetchMessages() {
    _isLoading = true;
    notifyListeners();
    _messagesSubscription?.cancel();
    if (_chatId == null) return;

    CollectionReference messagesCollection;
    if (_isSupportChat) {
      messagesCollection = _firestore
          .collection('support_chats')
          .doc(_chatId)
          .collection('messages');
    } else {
      messagesCollection =
          _firestore.collection('chats').doc(_chatId).collection('messages');
    }

    _messagesSubscription = messagesCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _messages =
          snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print('❌ خطأ في جلب الرسائل: $error');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> sendMessage(String text) async {
    final currentUser = _authProvider.currentUser;
    final currentUserProfile = _authProvider.currentUserProfile;
    if (text.trim().isEmpty || currentUser == null || _chatId == null) return;

    final message = ChatMessage(
      id: '',
      text: text,
      senderId: currentUser.uid,
      timestamp: Timestamp.now(),
    );

    try {
      if (_isSupportChat) {
        final supportChatDoc =
            _firestore.collection('support_chats').doc(_chatId);
        await supportChatDoc.collection('messages').add(message.toFirestore());
        await supportChatDoc.set({
          'lastMessage': text,
          'lastMessageTimestamp': message.timestamp,
          'userName': currentUserProfile?.name ?? 'مستخدم',
          'userImage': currentUserProfile?.profileImageUrl,
        }, SetOptions(merge: true));
      } else {
        final chatDoc = _firestore.collection('chats').doc(_chatId);
        await chatDoc.collection('messages').add(message.toFirestore());
        await chatDoc.update({
          'lastMessage': text,
          'lastMessageTimestamp': message.timestamp,
        });
      }
    } catch (e) {
      print('❌ فشل في إرسال الرسالة: $e');
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }
}

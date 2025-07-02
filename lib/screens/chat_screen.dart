// lib/screens/chat_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cure_app/models/chat_message.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:cure_app/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String partnerName;

  // هل هذه محادثة دعم فني؟
  final bool isSupportChat;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.partnerName,
    this.isSupportChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    final text = _textController.text.trim();
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (text.isEmpty || currentUser == null) return;

    final message = ChatMessage(
      id: '',
      text: text,
      senderId: currentUser.uid,
      timestamp: Timestamp.now(),
    );

    // تحديد المسار الصحيح لإضافة الرسالة
    String collectionPath = widget.isSupportChat ? 'support_chats' : 'chats';

    FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(widget.chatId)
        .collection('messages')
        .add(message.toFirestore());

    _textController.clear();
    // تحريك القائمة لأسفل لإظهار آخر رسالة
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    String collectionPath = widget.isSupportChat ? 'support_chats' : 'chats';

    return Scaffold(
      appBar: AppBar(title: Text(widget.partnerName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collectionPath)
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator();
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('ابدأ المحادثة!'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final message = ChatMessage.fromFirestore(messageDoc);
                    final isMe =
                        message.senderId == authProvider.currentUser?.uid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isMe ? kPrimaryColor : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // حقل إدخال النص
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    // --- ✨ التعديلات الجديدة هنا ---
                    keyboardType:
                        TextInputType.multiline, // للسماح بإدخال أسطر متعددة
                    minLines: 1, // يبدأ بسطر واحد
                    maxLines: 3, // ويتمدد حتى 3 أسطر كحد أقصى
                    // --- نهاية التعديلات ---
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25)),
                      // ✅ تحسين إضافي: جعل الحقل أصغر قليلاً وأكثر أناقة
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: kPrimaryColor),
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

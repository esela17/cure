// lib/screens/nurse/nurse_chats_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/screens/chat_screen.dart';
import 'package:cure_app/widgets/empty_state.dart';
import 'package:cure_app/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;

class NurseChatsScreen extends StatelessWidget {
  const NurseChatsScreen({super.key});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return intl.DateFormat('hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final nurseId = authProvider.currentUser?.uid;

    if (nurseId == null) {
      return const Scaffold(
        body: Center(
          child: Text('المستخدم غير مسجل أو لا يملك صلاحية.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحادثات'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب كل المحادثات التي يشارك فيها الممرض الحالي
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: nurseId)
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyState(
              message: 'لا توجد محادثات لديك.',
              icon: Icons.chat_bubble_outline_rounded,
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final chatDoc = snapshot.data!.docs[index];
              final chatData = chatDoc.data() as Map<String, dynamic>;

              // استخراج بيانات المشاركين من مستند المحادثة
              final participants = chatData['participants'] as List<dynamic>;
              final Map<String, dynamic> names =
                  chatData['participantNames'] ?? {};
              final Map<String, dynamic> images =
                  chatData['participantImages'] ?? {};

              // تحديد هوية الطرف الآخر في المحادثة
              final String otherUserId = participants
                  .firstWhere((id) => id != nurseId, orElse: () => '');
              final String otherUserName = names[otherUserId] ?? 'مستخدم';
              final String? otherUserImageUrl = images[otherUserId];
              final String lastMessage = chatData['lastMessage'] ?? '...';
              final Timestamp? lastMessageTimestamp =
                  chatData['lastMessageTimestamp'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: otherUserImageUrl != null
                        ? NetworkImage(otherUserImageUrl)
                        : null,
                    child: otherUserImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    otherUserName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _formatTimestamp(lastMessageTimestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatId: chatDoc.id,
                          partnerName: otherUserName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

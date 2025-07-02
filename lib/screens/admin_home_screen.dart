// lib/screens/admin/admin_home_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/screens/chat_screen.dart';
import 'package:cure_app/widgets/empty_state.dart';
import 'package:cure_app/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return intl.DateFormat('hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الدعم الفني'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Provider.of<AuthProvider>(context, listen: false)
                .signOut(context),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_chats')
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
              message: 'لا توجد محادثات دعم حالياً.',
              icon: Icons.chat_bubble_outline_rounded,
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final chatDoc = snapshot.data!.docs[index];
              final chatData = chatDoc.data() as Map<String, dynamic>;
              final userName = chatData['userName'] ?? 'مستخدم';
              final lastMessage = chatData['lastMessage'] ?? '';
              final userImage = chatData['userImage'];
              final timestamp = chatData['lastMessageTimestamp'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage:
                        userImage != null ? NetworkImage(userImage) : null,
                    child: userImage == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(userName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(lastMessage,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    _formatTimestamp(timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    // عند الضغط، افتح شاشة المحادثة
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: chatDoc
                              .id, // معرّف المحادثة هو uid الخاص بالمستخدم
                          partnerName: 'دعم لـ: $userName',
                          isSupportChat: true, // مهم جداً لتمييز المحادثة
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

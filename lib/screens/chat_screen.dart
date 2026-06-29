import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatScreen extends StatefulWidget {
  final String ticketId;
  final String ticketTitle;

  const ChatScreen({
    super.key,
    required this.ticketId,
    required this.ticketTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  late final DatabaseReference _chatRef;
  final _currentUser = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _chatRef = FirebaseDatabase.instance
        .ref()
        .child('chats')
        .child(widget.ticketId);
  }

  // FUNCTION 1 — builds ONE message bubble
  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message['senderName'] ?? 'Unknown',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.indigo.shade200 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message['text'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FUNCTION 2 — sends a message to Realtime Database
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final text = _messageController.text.trim();
    _messageController.clear();
    await _chatRef.push().set({
      'text': text,
      'senderId': _currentUser.uid,
      'senderName': _currentUser.email ?? 'User',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: Text(
          widget.ticketTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // PART 1 — messages list (takes all space)
          Expanded(
            child: StreamBuilder(
              stream: _chatRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }

                final data = Map<String, dynamic>.from(
                  snapshot.data!.snapshot.value as Map,
                );

                final messageList = data.entries.toList()
                  ..sort((a, b) {
                    final aTime = (a.value['timestamp'] ?? 0) as int;
                    final bTime = (b.value['timestamp'] ?? 0) as int;
                    return aTime.compareTo(bTime);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messageList.length,
                  itemBuilder: (context, index) {
                    final message = Map<String, dynamic>.from(
                      messageList[index].value,
                    );
                    final isMe = message['senderId'] == _currentUser.uid;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),

          // PART 2 — input bar at the bottom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Text field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.indigo,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

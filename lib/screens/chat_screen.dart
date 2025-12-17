import 'package:flutter/material.dart';

// Chat screen - equivalent to app/chat/page.tsx

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: const Center(
        child: Text('Chat Screen - To be implemented'),
      ),
    );
  }
}


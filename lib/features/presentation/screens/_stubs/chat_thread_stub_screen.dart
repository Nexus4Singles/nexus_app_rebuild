import 'package:flutter/material.dart';

class ChatThreadStubScreen extends StatelessWidget {
  final String chatId;

  const ChatThreadStubScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat $chatId')),
      body: Center(child: Text('Chat Thread (stub): $chatId')),
    );
  }
}

import 'package:flutter/material.dart';

class StoryDetailScreen extends StatelessWidget {
  final String storyId;
  const StoryDetailScreen({super.key, required this.storyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Story Detail')),
      body: Center(child: Text('Story: $storyId')),
    );
  }
}

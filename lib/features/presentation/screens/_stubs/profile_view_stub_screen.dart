import 'package:flutter/material.dart';

class ProfileViewStubScreen extends StatelessWidget {
  final String userId;

  const ProfileViewStubScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile $userId')),
      body: Center(child: Text('Profile View (stub): $userId')),
    );
  }
}

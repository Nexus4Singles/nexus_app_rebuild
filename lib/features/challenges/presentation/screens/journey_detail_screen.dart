import 'package:flutter/material.dart';

class JourneyDetailScreen extends StatelessWidget {
  final String journeyId;

  const JourneyDetailScreen({super.key, required this.journeyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journey')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journey: $journeyId',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text('Detail screen (Phase 2: fetch + render)'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pushNamed('/journey/$journeyId/session/1'),
                child: const Text('Start session 1'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

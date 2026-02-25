import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const AudioTestApp());
}

class AudioTestApp extends StatelessWidget {
  const AudioTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const AudioTestScreen());
  }
}

class AudioTestScreen extends StatefulWidget {
  const AudioTestScreen({Key? key}) : super(key: key);

  @override
  State<AudioTestScreen> createState() => _AudioTestScreenState();
}

class _AudioTestScreenState extends State<AudioTestScreen> {
  final _player = AudioPlayer();
  String _result = 'Ready to test';

  Future<void> _testUrl(String url, String label) async {
    setState(() => _result = 'Testing $label...');
    debugPrint('🧪 TEST: Attempting to play: $url');
    try {
      await _player.play(UrlSource(url));
      setState(() => _result = '✅ $label: PLAYING');
      debugPrint('✅ $label: Success!');
    } catch (e) {
      setState(() => _result = '❌ $label: $e');
      debugPrint('❌ $label: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Test')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Result: $_result', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    () => _testUrl(
                      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
                      'Public MP3',
                    ),
                child: const Text('Test 1: Public MP3'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed:
                    () => _testUrl(
                      'https://nexus-userdata.ams3.digitaloceanspaces.com/audio/ohukajames29%40gmail.com/1761216636306',
                      'V1 Audio (encoded @)',
                    ),
                child: const Text('Test 2: V1 Audio'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed:
                    () => _testUrl(
                      'https://nexus-userdata.ams3.digitaloceanspaces.com/audio/ohukajames29@gmail.com/1761216636306',
                      'V1 Audio (raw @)',
                    ),
                child: const Text('Test 3: V1 Audio (raw @)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

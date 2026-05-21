import 'package:flutter/material.dart';
import 'package:prysm_video_player/prysm_video_player.dart';

void main() {
  runApp(const PrysmExampleApp());
}

class PrysmExampleApp extends StatefulWidget {
  const PrysmExampleApp({super.key});

  @override
  State<PrysmExampleApp> createState() => _PrysmExampleAppState();
}

class _PrysmExampleAppState extends State<PrysmExampleApp> {
  late final PrysmVideoController controller;

  @override
  void initState() {
    super.initState();
    controller = PrysmVideoController(
      source: PrysmVideoSource.network(
        url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        title: 'Prysm HLS demo',
        subtitle: 'media_kit backend',
      ),
      config: const PrysmVideoConfig(autoPlay: false, aspectRatio: 16 / 9),
    );
    controller.events.listen((event) {
      debugPrint('Prysm event: ${event.type.name}');
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF101010),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: PrysmVideoPlayer(
              controller: controller,
              theme: const PrysmVideoTheme.dark(),
            ),
          ),
        ),
      ),
    );
  }
}

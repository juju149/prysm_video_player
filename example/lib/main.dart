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

  // ── Seek-preview configuration ─────────────────────────────────────────────
  //
  // Default: timecodeOnly — shows a timecode bubble with no image.
  // This is the safest default because it requires no external sprite.
  //
  // To enable image thumbnails, swap in one of the commented strategies below.
  // See docs/public_api.md for details.
  final PrysmThumbnailConfig _thumbnails =
      const PrysmThumbnailConfig.timecodeOnly();

  // ── Option A: sprite-sheet ─────────────────────────────────────────────────
  // Generate with:
  //   ffmpeg -i video.mp4 -vf "fps=0.1,scale=160:90,tile=10x8" sprites.jpg
  //
  // const PrysmThumbnailConfig _thumbnails = PrysmThumbnailConfig(
  //   provider: PrysmSpriteThumbnailProvider(
  //     sprite: NetworkImage('https://your-cdn.example.com/sprites.jpg'),
  //     interval: Duration(seconds: 10),
  //     columns: 10,
  //     rows: 8,
  //   ),
  //   previewWidth: 160,
  //   previewHeight: 90,
  // );

  // ── Option B: list of individual images ───────────────────────────────────
  // const PrysmThumbnailConfig _thumbnails = PrysmThumbnailConfig(
  //   provider: PrysmListThumbnailProvider([
  //     PrysmThumbnailEntry(
  //       timestamp: Duration.zero,
  //       image: NetworkImage('https://your-cdn.example.com/thumb_00.jpg'),
  //     ),
  //     PrysmThumbnailEntry(
  //       timestamp: Duration(seconds: 30),
  //       image: NetworkImage('https://your-cdn.example.com/thumb_30.jpg'),
  //     ),
  //   ]),
  // );

  @override
  void initState() {
    super.initState();
    controller = PrysmVideoController(
      source: PrysmVideoSource.network(
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
        title: 'Tears of Steel',
        subtitle: 'Seek preview demo — hover or drag the progress bar',
      ),
      config: const PrysmVideoConfig(autoPlay: true, aspectRatio: 16 / 9),
    );
    controller.events.listen((event) {
      debugPrint('[Prysm] ${event.type.name}');
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
              thumbnails: _thumbnails,
            ),
          ),
        ),
      ),
    );
  }
}



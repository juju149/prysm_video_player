import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prysm_video_player/prysm_video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PrysmVideoKit.ensureInitialized();
  runApp(const PrysmExampleApp());
}

class PrysmExampleApp extends StatefulWidget {
  const PrysmExampleApp({super.key});

  @override
  State<PrysmExampleApp> createState() => _PrysmExampleAppState();
}

class _PrysmExampleAppState extends State<PrysmExampleApp> {
  static const _mp4 =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  late final PrysmVideoController controller;
  final List<String> _events = <String>[];
  bool _tvMode = false;

  final PrysmThumbnailConfig _thumbnails =
      const PrysmThumbnailConfig.timecodeOnly();

  final PrysmVideoSource _cachedMp4 = PrysmVideoSource.network(
    url: _mp4,
    title: 'Big Buck Bunny',
    subtitle: 'Cached MP4, custom UI, subtitles and analytics',
    subtitles: <PrysmSubtitleTrack>[
      PrysmSubtitleTrack(
        id: 'demo-en',
        label: 'English demo',
        languageCode: 'en',
        defaultTrack: true,
        source: PrysmSubtitleSource.data('''
WEBVTT

00:00:00.000 --> 00:00:04.000
Prysm demo subtitle

00:00:04.000 --> 00:00:08.000
Fine-grained custom controls
'''),
      ),
    ],
  );

  final PrysmVideoSource _qualityDemo = PrysmVideoSource.multiQuality(
    title: 'Quality selector demo',
    poster:
        'https://peach.blender.org/wp-content/uploads/title_anouncement.jpg',
    qualities: const <PrysmVideoQuality>[
      PrysmVideoQuality(
        id: '360p',
        label: '360p',
        height: 360,
        url:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      ),
      PrysmVideoQuality(id: '720p', label: '720p', height: 720, url: _mp4),
    ],
  );

  @override
  void initState() {
    super.initState();
    controller = PrysmVideoController(
      source: _cachedMp4,
      config: const PrysmVideoConfig(
        autoPlay: false,
        aspectRatio: 16 / 9,
        cache: PrysmCacheConfig(policy: PrysmCachePolicy.fullFile),
        enablePictureInPicture: true,
        enableMediaNotifications: true,
        enableBackgroundAudio: true,
      ),
      cache: createPrysmVideoCache(),
      pictureInPicture: PrysmPlatformPictureInPictureAdapter(),
      mediaIntegration: PrysmPlatformMediaIntegration(),
      drmAdapter: PrysmHttpDrmLicenseAdapter(),
      castAdapter: const PrysmNoopCastAdapter(),
    );
    controller.events.listen((event) {
      setState(() {
        _events.insert(0, '${event.type.name} @ ${event.position.inSeconds}s');
        if (_events.length > 8) _events.removeLast();
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _tvMode
        ? const PrysmVideoTheme.tv()
        : const PrysmVideoTheme.dark();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF101010),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    _ExampleToolbar(
                      tvMode: _tvMode,
                      onTvModeChanged: (value) {
                        setState(() => _tvMode = value);
                      },
                      onCachedMp4: () => controller.open(_cachedMp4),
                      onQualityDemo: () => controller.open(_qualityDemo),
                    ),
                    const SizedBox(height: 12),
                    PrysmVideoPlayer(
                      controller: controller,
                      theme: theme,
                      thumbnails: _thumbnails,
                      customization: _customization,
                    ),
                    const SizedBox(height: 12),
                    _EventPanel(events: _events),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PrysmVideoCustomization get _customization {
    return PrysmVideoCustomization(
      loadingBuilder: (context, details) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            details.child,
            const SizedBox(height: 10),
            const Text('Preparing stream and cache'),
          ],
        );
      },
      errorBuilder: (context, details) {
        return Card(
          color: const Color(0xFF241313),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(details.error?.userMessage ?? 'Playback failed'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: details.retry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
      topBarBuilder: (context, details) {
        return Row(
          children: <Widget>[
            Expanded(child: details.child),
            const SizedBox(width: 12),
            Chip(label: Text(details.context.platform.name.toUpperCase())),
          ],
        );
      },
      progressBarBuilder: (context, details) {
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: details.child,
          ),
        );
      },
      speedPickerBuilder: _pickerShell,
      qualityPickerBuilder: _pickerShell,
      subtitlePickerBuilder: _pickerShell,
      audioPickerBuilder: _pickerShell,
      subtitleRendererBuilder: (context, details) {
        if (details.selectedTrack.id == 'no') return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: details.subtitleStyle.bottomOffset + 28,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'Custom subtitle renderer slot',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        );
      },
      keyboardShortcutHandler: (context, details) {
        if (details.event.logicalKey == LogicalKeyboardKey.keyL) {
          details.context.controller.setLooping(!details.context.state.looping);
          return KeyEventResult.handled;
        }
        return details.defaultResult;
      },
      tvFocusBuilder: (context, details) {
        return PrysmTvFocusBorder(
          focused: details.focused,
          child: details.child,
        );
      },
    );
  }

  Widget _pickerShell<T>(
    BuildContext context,
    PrysmTrackPickerDetails<T> details,
  ) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF101820)),
      child: details.child,
    );
  }
}

class _ExampleToolbar extends StatelessWidget {
  const _ExampleToolbar({
    required this.tvMode,
    required this.onTvModeChanged,
    required this.onCachedMp4,
    required this.onQualityDemo,
  });

  final bool tvMode;
  final ValueChanged<bool> onTvModeChanged;
  final VoidCallback onCachedMp4;
  final VoidCallback onQualityDemo;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        FilledButton(onPressed: onCachedMp4, child: const Text('Cached MP4')),
        FilledButton.tonal(
          onPressed: onQualityDemo,
          child: const Text('Quality demo'),
        ),
        FilterChip(
          selected: tvMode,
          label: const Text('TV theme'),
          onSelected: onTvModeChanged,
        ),
        const Chip(label: Text('No-op cast adapter')),
        const Chip(label: Text('Platform PiP/media adapters')),
      ],
    );
  }
}

class _EventPanel extends StatelessWidget {
  const _EventPanel({required this.events});

  final List<String> events;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            const Text(
              'Analytics events',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const Text('No events yet')
            else
              for (final event in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(event),
                ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:prysm_video_player/prysm_video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrysmVideoSource', () {
    test('creates network source with headers and metadata', () {
      final source = PrysmVideoSource.network(
        url: 'https://example.com/movie.m3u8',
        headers: const <String, String>{'Authorization': 'Bearer token'},
        title: 'Movie',
        poster: 'https://example.com/poster.jpg',
      );

      expect(source.type, PrysmVideoSourceType.hls);
      expect(source.uri, 'https://example.com/movie.m3u8');
      expect(source.headers, {'Authorization': 'Bearer token'});
      expect(source.protected, isTrue);
    });

    test('normalizes asset paths', () {
      final source = PrysmVideoSource.asset('assets/video.mp4');

      expect(source.type, PrysmVideoSourceType.asset);
      expect(source.uri, 'asset:///assets/video.mp4');
    });

    test('creates multi-quality source', () {
      final source = PrysmVideoSource.multiQuality(
        qualities: const <PrysmVideoQuality>[
          PrysmVideoQuality(
            id: '720p',
            label: '720p',
            height: 720,
            url: 'https://cdn/720.mp4',
          ),
        ],
      );

      expect(source.isMultiQuality, isTrue);
      expect(source.qualities.first, const PrysmVideoQuality.auto());
    });
  });

  group('PrysmVideoState', () {
    test('calculates progress and buffer progress', () {
      const state = PrysmVideoState(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 120),
        bufferedPosition: Duration(seconds: 60),
      );

      expect(state.progress, 0.25);
      expect(state.bufferProgress, 0.5);
    });

    test('config defaults are conservative', () {
      const config = PrysmVideoConfig();

      expect(config.autoPlay, isFalse);
      expect(config.initialSpeed, 1);
      expect(config.preferredQuality, const PrysmVideoQuality.auto());
    });
  });

  group('Errors', () {
    test('maps common network errors', () {
      final error = PrysmVideoError.map(Exception('HTTP 401 unauthorized'));

      expect(error.kind, PrysmVideoErrorKind.unauthorized);
      expect(error.retryable, isFalse);
    });
  });

  group('Subtitles', () {
    const parser = PrysmSubtitleParser();

    test('parses SRT cues', () {
      final cues = parser.parseSrt('''
1
00:00:01,000 --> 00:00:02,500
Bonjour

2
00:00:03,000 --> 00:00:04,000
Suite
''');

      expect(cues, hasLength(2));
      expect(cues.first.start, const Duration(seconds: 1));
      expect(cues.first.end, const Duration(milliseconds: 2500));
      expect(cues.first.text, 'Bonjour');
    });

    test('parses WebVTT cues', () {
      final cues = parser.parseWebVtt('''
WEBVTT

00:00:01.000 --> 00:00:02.000
Hello
''');

      expect(cues, hasLength(1));
      expect(cues.first.text, 'Hello');
    });
  });

  group('Theme', () {
    test('theme defaults include labels and subtitle style', () {
      const theme = PrysmVideoTheme.dark();

      expect(theme.labels.play, 'Play');
      expect(theme.subtitleStyle.bottomOffset, 72);
    });
  });

  group('Controller safety', () {
    test('cannot be used after dispose', () async {
      final controller = PrysmVideoController(backend: _FakeBackend());
      controller.dispose();

      expect(controller.isDisposed, isTrue);
      expect(controller.play, throwsA(isA<PrysmDisposedVideoError>()));
    });

    test('event stream emits disposed', () async {
      final controller = PrysmVideoController(backend: _FakeBackend());
      final events = <PrysmVideoEvent>[];
      final subscription = controller.events.listen(events.add);

      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(
        events.map((event) => event.type),
        contains(PrysmVideoEventType.disposed),
      );
    });

    testWidgets('TV focus border renders focused state', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PrysmTvFocusBorder(focused: true, child: Text('focused')),
        ),
      );

      expect(find.text('focused'), findsOneWidget);
    });
  });
}

class _FakeBackend implements PrysmPlaybackBackend {
  @override
  VideoController get videoController => throw UnimplementedError();

  @override
  Stream<bool> get playing => const Stream<bool>.empty();

  @override
  Stream<bool> get completed => const Stream<bool>.empty();

  @override
  Stream<bool> get buffering => const Stream<bool>.empty();

  @override
  Stream<Duration> get position => const Stream<Duration>.empty();

  @override
  Stream<Duration> get duration => const Stream<Duration>.empty();

  @override
  Stream<Duration> get buffer => const Stream<Duration>.empty();

  @override
  Stream<double> get volume => const Stream<double>.empty();

  @override
  Stream<double> get speed => const Stream<double>.empty();

  @override
  Stream<Object> get errors => const Stream<Object>.empty();

  @override
  Stream<PrysmAvailableTracks> get availableTracks {
    return const Stream<PrysmAvailableTracks>.empty();
  }

  @override
  Stream<PrysmSelectedTracks> get selectedTracks {
    return const Stream<PrysmSelectedTracks>.empty();
  }

  @override
  PrysmAvailableTracks get currentAvailableTracks =>
      const PrysmAvailableTracks();

  @override
  PrysmSelectedTracks get currentSelectedTracks => const PrysmSelectedTracks();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> open(
    PrysmVideoSource source, {
    PrysmVideoQuality? quality,
    bool play = true,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> playOrPause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> selectAudioTrack(String id) async {}

  @override
  Future<void> selectSubtitleTrack(String id) async {}

  @override
  Future<void> selectVideoTrack(String id) async {}

  @override
  Future<void> setLooping(bool enabled) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

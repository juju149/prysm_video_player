import 'dart:async';

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

    test('opens cached source when cache resolves to a file', () async {
      final backend = _FakeBackend();
      final source = PrysmVideoSource.network(url: 'https://cdn/movie.mp4');
      final controller = PrysmVideoController(
        backend: backend,
        cache: _FakeCache(source.asCachedFile('/tmp/movie.mp4')),
        config: const PrysmVideoConfig(
          cache: PrysmCacheConfig(policy: PrysmCachePolicy.fullFile),
        ),
      );
      final events = <PrysmVideoEvent>[];
      final subscription = controller.events.listen(events.add);

      await controller.open(source);
      await Future<void>.delayed(Duration.zero);

      expect(backend.openedSource?.type, PrysmVideoSourceType.file);
      expect(
        events.map((event) => event.type),
        contains(PrysmVideoEventType.cacheResolved),
      );

      await subscription.cancel();
      controller.dispose();
    });

    test('picture-in-picture adapter updates state', () async {
      final controller = PrysmVideoController(
        backend: _FakeBackend(),
        pictureInPicture: const _FakePictureInPictureAdapter(),
        config: const PrysmVideoConfig(enablePictureInPicture: true),
      );

      await controller.enablePictureInPicture();

      expect(controller.state.pictureInPicture, isTrue);
      controller.dispose();
    });

    test('remote media commands are routed to playback commands', () async {
      final backend = _FakeBackend();
      final media = _FakeMediaIntegration();
      final controller = PrysmVideoController(
        backend: backend,
        mediaIntegration: media,
      );

      media.add(const PrysmRemoteCommand(type: PrysmRemoteCommandType.play));
      await Future<void>.delayed(Duration.zero);

      expect(backend.playCalls, 1);
      controller.dispose();
      await media.dispose();
    });

    test('cast adapter starts and stops a session', () async {
      final controller = PrysmVideoController(
        source: PrysmVideoSource.network(url: 'https://cdn/movie.mp4'),
        backend: _FakeBackend(),
        castAdapter: const _FakeCastAdapter(),
      );
      const device = PrysmCastDevice(
        id: 'living-room',
        name: 'Living Room',
        type: PrysmCastDeviceType.chromecast,
      );

      final session = await controller.startCasting(device);

      expect(session.active, isTrue);
      expect(controller.state.casting, isTrue);

      await controller.stopCasting();
      expect(controller.state.casting, isFalse);
      controller.dispose();
    });
  });
}

class _FakeBackend implements PrysmPlaybackBackend {
  PrysmVideoSource? openedSource;
  int playCalls = 0;

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
  }) async {
    openedSource = source;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {
    playCalls++;
  }

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

class _FakeCache implements PrysmVideoCache {
  const _FakeCache(this.source);

  final PrysmVideoSource source;

  @override
  Future<void> clear() async {}

  @override
  Future<void> evict(String cacheKey) async {}

  @override
  Future<PrysmCacheResolveResult> resolve(
    PrysmVideoSource source,
    PrysmCacheConfig config,
  ) async {
    return PrysmCacheResolveResult(
      source: this.source,
      reason: PrysmCacheResolveReason.hit,
      cacheKey: 'cache-key',
      path: this.source.uri,
    );
  }
}

class _FakePictureInPictureAdapter implements PrysmPictureInPictureAdapter {
  const _FakePictureInPictureAdapter();

  @override
  Future<PrysmPictureInPictureState> enter(PrysmVideoState videoState) async {
    return const PrysmPictureInPictureState(
      support: PrysmPictureInPictureSupport.platformCustom,
      enabled: true,
    );
  }

  @override
  Future<PrysmPictureInPictureState> exit() async {
    return const PrysmPictureInPictureState(
      support: PrysmPictureInPictureSupport.platformCustom,
    );
  }

  @override
  Future<PrysmPictureInPictureState> state() async {
    return const PrysmPictureInPictureState(
      support: PrysmPictureInPictureSupport.platformCustom,
    );
  }
}

class _FakeMediaIntegration implements PrysmMediaIntegration {
  final StreamController<PrysmRemoteCommand> _commands =
      StreamController<PrysmRemoteCommand>.broadcast();

  void add(PrysmRemoteCommand command) => _commands.add(command);

  @override
  Stream<PrysmRemoteCommand> get remoteCommands => _commands.stream;

  @override
  Future<void> dispose() => _commands.close();

  @override
  Future<void> setBackgroundAudioEnabled(bool enabled) async {}

  @override
  Future<void> setMetadata(PrysmMediaMetadata metadata) async {}

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> setPlayback(PrysmMediaPlaybackSnapshot playback) async {}
}

class _FakeCastAdapter implements PrysmCastAdapter {
  const _FakeCastAdapter();

  @override
  Future<List<PrysmCastDevice>> discover() async {
    return const <PrysmCastDevice>[];
  }

  @override
  Future<PrysmCastSession> start({
    required PrysmCastDevice device,
    required PrysmVideoSource source,
    Duration position = Duration.zero,
  }) async {
    return PrysmCastSession(device: device, active: true);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> updatePosition(Duration position) async {}
}

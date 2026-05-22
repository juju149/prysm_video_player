import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:prysm_video_player/prysm_video_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Prysm smoke tests', () {
    testWidgets('open source', (tester) async {
      final backend = _SmokeBackend();
      final controller = PrysmVideoController(backend: backend);

      await controller.open(PrysmVideoSource.network(url: 'https://cdn/v.mp4'));

      expect(backend.openedSource?.uri, 'https://cdn/v.mp4');
      expect(controller.state.status, PrysmPlaybackStatus.ready);
      controller.dispose();
    });

    testWidgets('play and pause', (tester) async {
      final backend = _SmokeBackend();
      final controller = PrysmVideoController(backend: backend);

      await controller.play();
      await controller.pause();

      expect(backend.playCalls, 1);
      expect(backend.pauseCalls, 1);
      controller.dispose();
    });

    testWidgets('seek', (tester) async {
      final backend = _SmokeBackend();
      final controller = PrysmVideoController(backend: backend);

      await controller.seekTo(const Duration(seconds: 42));

      expect(backend.seekPosition, const Duration(seconds: 42));
      controller.dispose();
    });

    testWidgets('error source maps to controller error', (tester) async {
      final controller = PrysmVideoController(
        backend: _SmokeBackend(openError: Exception('HTTP 404 not found')),
      );

      await expectLater(
        controller.open(PrysmVideoSource.network(url: 'https://cdn/404.mp4')),
        throwsA(isA<PrysmVideoError>()),
      );

      expect(controller.state.status, PrysmPlaybackStatus.error);
      expect(controller.state.error?.kind, PrysmVideoErrorKind.notFound);
      controller.dispose();
    });

    testWidgets('fullscreen route enters and exits fullscreen state', (
      tester,
    ) async {
      final controller = PrysmVideoController(backend: _SmokeBackend());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PrysmFullscreenRoute(
                      controller: controller,
                      config: const PrysmVideoConfig(),
                      theme: const PrysmVideoTheme.dark(),
                      surfaceBuilder: _fakeSurface,
                    ),
                  );
                },
                child: const Text('fullscreen'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('fullscreen'));
      await tester.pumpAndSettle();

      expect(controller.state.fullscreen, isTrue);

      Navigator.of(
        tester.element(find.byKey(const ValueKey('fake-surface'))),
      ).pop();
      await tester.pumpAndSettle();

      expect(controller.state.fullscreen, isFalse);
      controller.dispose();
    });

    testWidgets('controller dispose guards later calls', (tester) async {
      final controller = PrysmVideoController(backend: _SmokeBackend());

      controller.dispose();

      expect(controller.isDisposed, isTrue);
      expect(controller.play, throwsA(isA<PrysmDisposedVideoError>()));
    });
  });
}

Widget _fakeSurface(
  BuildContext context,
  PrysmVideoController controller,
  PrysmVideoState state,
) {
  return const ColoredBox(key: ValueKey('fake-surface'), color: Colors.black);
}

class _SmokeBackend implements PrysmPlaybackBackend {
  _SmokeBackend({this.openError});

  final Object? openError;
  PrysmVideoSource? openedSource;
  int playCalls = 0;
  int pauseCalls = 0;
  Duration? seekPosition;

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
  Stream<PrysmAvailableTracks> get availableTracks =>
      const Stream<PrysmAvailableTracks>.empty();

  @override
  Stream<PrysmSelectedTracks> get selectedTracks =>
      const Stream<PrysmSelectedTracks>.empty();

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
    if (openError != null) throw openError!;
    openedSource = source;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> playOrPause() async {}

  @override
  Future<void> seek(Duration position) async {
    seekPosition = position;
  }

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

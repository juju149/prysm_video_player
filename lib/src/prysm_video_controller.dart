import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'prysm_video_options.dart';
import 'prysm_video_source.dart';

class PrysmVideoKit {
  const PrysmVideoKit._();

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    MediaKit.ensureInitialized();
    _initialized = true;
  }
}

class PrysmVideoSnapshot {
  const PrysmVideoSnapshot({
    this.playing = false,
    this.completed = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffer = Duration.zero,
    this.volume = 100,
    this.rate = 1,
    this.error,
  });

  final bool playing;
  final bool completed;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final double volume;
  final double rate;
  final String? error;

  double get progress {
    if (duration <= Duration.zero) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  double get bufferProgress {
    if (duration <= Duration.zero) return 0;
    return (buffer.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool get muted => volume <= 0;

  PrysmVideoSnapshot copyWith({
    bool? playing,
    bool? completed,
    bool? buffering,
    Duration? position,
    Duration? duration,
    Duration? buffer,
    double? volume,
    double? rate,
    String? error,
    bool clearError = false,
  }) {
    return PrysmVideoSnapshot(
      playing: playing ?? this.playing,
      completed: completed ?? this.completed,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffer: buffer ?? this.buffer,
      volume: volume ?? this.volume,
      rate: rate ?? this.rate,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PrysmVideoController extends ChangeNotifier {
  factory PrysmVideoController({
    PrysmVideoOptions options = const PrysmVideoOptions(),
    Player? player,
  }) {
    return PrysmVideoController.create(options: options, player: player);
  }

  PrysmVideoController._({
    required this.player,
    required this.videoController,
    required this._ownsPlayer,
    PrysmVideoOptions options = const PrysmVideoOptions(),
  }) {
    PrysmVideoKit.ensureInitialized();
    _snapshot = PrysmVideoSnapshot(
      volume: options.muted ? 0 : options.initialVolume.clamp(0, 100),
      rate: options.initialRate.clamp(0.25, 4),
    );
    _bind();
    unawaited(setVolume(_snapshot.volume));
    unawaited(setRate(_snapshot.rate));
    unawaited(setLoop(options.loop));
  }

  factory PrysmVideoController.create({
    PrysmVideoOptions options = const PrysmVideoOptions(),
    Player? player,
  }) {
    PrysmVideoKit.ensureInitialized();
    final resolvedPlayer = player ?? Player();
    return PrysmVideoController._(
      player: resolvedPlayer,
      videoController: VideoController(resolvedPlayer),
      ownsPlayer: player == null,
      options: options,
    );
  }

  final Player player;
  final VideoController videoController;
  final bool _ownsPlayer;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  late PrysmVideoSnapshot _snapshot;
  double _lastAudibleVolume = 100;
  bool _disposed = false;

  PrysmVideoSnapshot get snapshot => _snapshot;

  void _bind() {
    _subscriptions
      ..add(
        player.stream.playing.listen((value) {
          _update(_snapshot.copyWith(playing: value));
        }),
      )
      ..add(
        player.stream.completed.listen((value) {
          _update(_snapshot.copyWith(completed: value));
        }),
      )
      ..add(
        player.stream.buffering.listen((value) {
          _update(_snapshot.copyWith(buffering: value));
        }),
      )
      ..add(
        player.stream.position.listen((value) {
          _update(_snapshot.copyWith(position: value));
        }),
      )
      ..add(
        player.stream.duration.listen((value) {
          _update(_snapshot.copyWith(duration: value));
        }),
      )
      ..add(
        player.stream.buffer.listen((value) {
          _update(_snapshot.copyWith(buffer: value));
        }),
      )
      ..add(
        player.stream.volume.listen((value) {
          if (value > 0) _lastAudibleVolume = value;
          _update(_snapshot.copyWith(volume: value));
        }),
      )
      ..add(
        player.stream.rate.listen((value) {
          _update(_snapshot.copyWith(rate: value));
        }),
      )
      ..add(
        player.stream.error.listen((value) {
          _update(_snapshot.copyWith(error: value));
        }),
      );
  }

  Future<void> open(PrysmVideoSource source, {bool play = true}) async {
    _update(_snapshot.copyWith(clearError: true));
    final media = await source.toMedia();
    await player.open(media, play: play);
  }

  Future<void> play() => player.play();

  Future<void> pause() => player.pause();

  Future<void> toggle() => player.playOrPause();

  Future<void> stop() => player.stop();

  Future<void> seek(Duration position) {
    final duration = _snapshot.duration;
    if (duration > Duration.zero) {
      final clampedMs = position.inMilliseconds.clamp(
        0,
        duration.inMilliseconds,
      );
      return player.seek(Duration(milliseconds: clampedMs));
    }
    return player.seek(position < Duration.zero ? Duration.zero : position);
  }

  Future<void> seekRelative(Duration delta) => seek(_snapshot.position + delta);

  Future<void> setVolume(double volume) {
    final value = volume.clamp(0.0, 100.0);
    if (value > 0) _lastAudibleVolume = value;
    return player.setVolume(value);
  }

  Future<void> toggleMute() {
    if (_snapshot.volume <= 0) {
      return setVolume(_lastAudibleVolume <= 0 ? 100 : _lastAudibleVolume);
    }
    _lastAudibleVolume = _snapshot.volume;
    return setVolume(0);
  }

  Future<void> setRate(double rate) => player.setRate(rate.clamp(0.25, 4.0));

  Future<void> setLoop(bool enabled) =>
      player.setPlaylistMode(enabled ? PlaylistMode.loop : PlaylistMode.none);

  void _update(PrysmVideoSnapshot next) {
    if (_disposed) return;
    _snapshot = next;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    if (_ownsPlayer) {
      await player.dispose();
    }
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/services.dart';

import '../core/prysm_video_state.dart';

enum PrysmRemoteCommandType {
  play,
  pause,
  toggle,
  stop,
  seekTo,
  seekBy,
  forward,
  replay,
  mute,
  unmute,
}

class PrysmRemoteCommand {
  const PrysmRemoteCommand({required this.type, this.position, this.delta});

  final PrysmRemoteCommandType type;
  final Duration? position;
  final Duration? delta;
}

class PrysmMediaMetadata {
  const PrysmMediaMetadata({
    this.title,
    this.subtitle,
    this.poster,
    this.duration = Duration.zero,
    this.live = false,
  });

  factory PrysmMediaMetadata.fromState(PrysmVideoState state) {
    final source = state.source;
    return PrysmMediaMetadata(
      title: source?.title,
      subtitle: source?.subtitle,
      poster: source?.poster,
      duration: state.duration,
      live: state.live,
    );
  }

  final String? title;
  final String? subtitle;
  final String? poster;
  final Duration duration;
  final bool live;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'subtitle': subtitle,
      'poster': poster,
      'durationMs': duration.inMilliseconds,
      'live': live,
    };
  }
}

class PrysmMediaPlaybackSnapshot {
  const PrysmMediaPlaybackSnapshot({
    required this.playing,
    required this.buffering,
    required this.position,
    required this.duration,
    required this.speed,
    required this.volume,
  });

  factory PrysmMediaPlaybackSnapshot.fromState(PrysmVideoState state) {
    return PrysmMediaPlaybackSnapshot(
      playing: state.playing,
      buffering: state.buffering,
      position: state.position,
      duration: state.duration,
      speed: state.speed,
      volume: state.volume,
    );
  }

  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'playing': playing,
      'buffering': buffering,
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      'speed': speed,
      'volume': volume,
    };
  }
}

abstract interface class PrysmMediaIntegration {
  Stream<PrysmRemoteCommand> get remoteCommands;

  Future<void> setMetadata(PrysmMediaMetadata metadata);

  Future<void> setPlayback(PrysmMediaPlaybackSnapshot playback);

  Future<void> setBackgroundAudioEnabled(bool enabled);

  Future<void> setNotificationsEnabled(bool enabled);

  Future<void> dispose();
}

class PrysmNoopMediaIntegration implements PrysmMediaIntegration {
  const PrysmNoopMediaIntegration();

  @override
  Stream<PrysmRemoteCommand> get remoteCommands => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> setBackgroundAudioEnabled(bool enabled) async {}

  @override
  Future<void> setMetadata(PrysmMediaMetadata metadata) async {}

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> setPlayback(PrysmMediaPlaybackSnapshot playback) async {}
}

class PrysmPlatformMediaIntegration implements PrysmMediaIntegration {
  PrysmPlatformMediaIntegration({
    MethodChannel? channel,
    EventChannel? eventChannel,
  }) : _channel = channel ?? const MethodChannel('prysm_video_player/media'),
       _eventChannel =
           eventChannel ??
           const EventChannel('prysm_video_player/media_events');

  final MethodChannel _channel;
  final EventChannel _eventChannel;

  @override
  late final Stream<PrysmRemoteCommand> remoteCommands = _eventChannel
      .receiveBroadcastStream()
      .map(_mapRemoteCommand)
      .where((command) => command != null)
      .cast<PrysmRemoteCommand>();

  @override
  Future<void> dispose() async {
    await _invoke('dispose');
  }

  @override
  Future<void> setBackgroundAudioEnabled(bool enabled) {
    return _invoke('setBackgroundAudioEnabled', <String, Object?>{
      'enabled': enabled,
    });
  }

  @override
  Future<void> setMetadata(PrysmMediaMetadata metadata) {
    return _invoke('setMetadata', metadata.toJson());
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) {
    return _invoke('setNotificationsEnabled', <String, Object?>{
      'enabled': enabled,
    });
  }

  @override
  Future<void> setPlayback(PrysmMediaPlaybackSnapshot playback) {
    return _invoke('setPlayback', playback.toJson());
  }

  Future<void> _invoke(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      return;
    }
  }

  PrysmRemoteCommand? _mapRemoteCommand(Object? event) {
    if (event is! Map) return null;
    final typeName = event['type'];
    if (typeName is! String) return null;
    final type = PrysmRemoteCommandType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => PrysmRemoteCommandType.toggle,
    );
    return PrysmRemoteCommand(
      type: type,
      position: _durationFromMs(event['positionMs']),
      delta: _durationFromMs(event['deltaMs']),
    );
  }

  Duration? _durationFromMs(Object? value) {
    if (value is! int) return null;
    return Duration(milliseconds: value);
  }
}

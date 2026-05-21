import 'package:flutter/widgets.dart';

import '../cache/prysm_cache_config.dart';
import '../tracks/prysm_tracks.dart';

/// Runtime behavior for a [PrysmVideoController].
class PrysmVideoConfig {
  const PrysmVideoConfig({
    this.autoPlay = false,
    this.looping = false,
    this.startAt = Duration.zero,
    this.preferredQuality = const PrysmVideoQuality.auto(),
    this.muted = false,
    this.initialVolume = 100,
    this.initialSpeed = 1,
    this.resumeFromLastPosition = false,
    this.tickInterval = const Duration(milliseconds: 250),
    this.positionThrottle = const Duration(milliseconds: 250),
    this.seekStep = const Duration(seconds: 10),
    this.bigSeekStep = const Duration(seconds: 30),
    this.fit = BoxFit.contain,
    this.aspectRatio,
    this.showControls = true,
    this.autoHideControls = true,
    this.controlsAutoHideDelay = const Duration(seconds: 3),
    this.enableGestures = true,
    this.enableKeyboard = true,
    this.enableTvControls = true,
    this.enableFullscreen = true,
    this.enablePictureInPicture = false,
    this.pauseWhenBackgrounded = true,
    this.resumeWhenForegrounded = false,
    this.cache = const PrysmCacheConfig.disabled(),
  });

  final bool autoPlay;
  final bool looping;
  final Duration startAt;
  final PrysmVideoQuality preferredQuality;
  final bool muted;
  final double initialVolume;
  final double initialSpeed;
  final bool resumeFromLastPosition;
  final Duration tickInterval;
  final Duration positionThrottle;
  final Duration seekStep;
  final Duration bigSeekStep;
  final BoxFit fit;
  final double? aspectRatio;
  final bool showControls;
  final bool autoHideControls;
  final Duration controlsAutoHideDelay;
  final bool enableGestures;
  final bool enableKeyboard;
  final bool enableTvControls;
  final bool enableFullscreen;
  final bool enablePictureInPicture;
  final bool pauseWhenBackgrounded;
  final bool resumeWhenForegrounded;
  final PrysmCacheConfig cache;

  PrysmVideoConfig copyWith({
    bool? autoPlay,
    bool? looping,
    Duration? startAt,
    PrysmVideoQuality? preferredQuality,
    bool? muted,
    double? initialVolume,
    double? initialSpeed,
    bool? resumeFromLastPosition,
    Duration? tickInterval,
    Duration? positionThrottle,
    Duration? seekStep,
    Duration? bigSeekStep,
    BoxFit? fit,
    double? aspectRatio,
    bool? showControls,
    bool? autoHideControls,
    Duration? controlsAutoHideDelay,
    bool? enableGestures,
    bool? enableKeyboard,
    bool? enableTvControls,
    bool? enableFullscreen,
    bool? enablePictureInPicture,
    bool? pauseWhenBackgrounded,
    bool? resumeWhenForegrounded,
    PrysmCacheConfig? cache,
  }) {
    return PrysmVideoConfig(
      autoPlay: autoPlay ?? this.autoPlay,
      looping: looping ?? this.looping,
      startAt: startAt ?? this.startAt,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      muted: muted ?? this.muted,
      initialVolume: initialVolume ?? this.initialVolume,
      initialSpeed: initialSpeed ?? this.initialSpeed,
      resumeFromLastPosition:
          resumeFromLastPosition ?? this.resumeFromLastPosition,
      tickInterval: tickInterval ?? this.tickInterval,
      positionThrottle: positionThrottle ?? this.positionThrottle,
      seekStep: seekStep ?? this.seekStep,
      bigSeekStep: bigSeekStep ?? this.bigSeekStep,
      fit: fit ?? this.fit,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      showControls: showControls ?? this.showControls,
      autoHideControls: autoHideControls ?? this.autoHideControls,
      controlsAutoHideDelay:
          controlsAutoHideDelay ?? this.controlsAutoHideDelay,
      enableGestures: enableGestures ?? this.enableGestures,
      enableKeyboard: enableKeyboard ?? this.enableKeyboard,
      enableTvControls: enableTvControls ?? this.enableTvControls,
      enableFullscreen: enableFullscreen ?? this.enableFullscreen,
      enablePictureInPicture:
          enablePictureInPicture ?? this.enablePictureInPicture,
      pauseWhenBackgrounded:
          pauseWhenBackgrounded ?? this.pauseWhenBackgrounded,
      resumeWhenForegrounded:
          resumeWhenForegrounded ?? this.resumeWhenForegrounded,
      cache: cache ?? this.cache,
    );
  }
}

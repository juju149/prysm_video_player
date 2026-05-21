import 'package:flutter/widgets.dart';

class PrysmVideoOptions {
  const PrysmVideoOptions({
    this.autoPlay = true,
    this.loop = false,
    this.muted = false,
    this.initialVolume = 100,
    this.initialRate = 1,
    this.fit = BoxFit.contain,
    this.aspectRatio,
    this.showControls = true,
    this.autoHideControls = true,
    this.controlsAutoHideDelay = const Duration(seconds: 3),
    this.seekStep = const Duration(seconds: 10),
    this.bigSeekStep = const Duration(seconds: 30),
    this.enableKeyboard = true,
    this.enableGestures = true,
    this.enableFullscreen = true,
    this.pauseWhenBackgrounded = true,
    this.resumeWhenForegrounded = false,
    this.title,
    this.subtitle,
  });

  final bool autoPlay;
  final bool loop;
  final bool muted;
  final double initialVolume;
  final double initialRate;
  final BoxFit fit;
  final double? aspectRatio;
  final bool showControls;
  final bool autoHideControls;
  final Duration controlsAutoHideDelay;
  final Duration seekStep;
  final Duration bigSeekStep;
  final bool enableKeyboard;
  final bool enableGestures;
  final bool enableFullscreen;
  final bool pauseWhenBackgrounded;
  final bool resumeWhenForegrounded;
  final String? title;
  final String? subtitle;

  PrysmVideoOptions copyWith({
    bool? autoPlay,
    bool? loop,
    bool? muted,
    double? initialVolume,
    double? initialRate,
    BoxFit? fit,
    double? aspectRatio,
    bool? showControls,
    bool? autoHideControls,
    Duration? controlsAutoHideDelay,
    Duration? seekStep,
    Duration? bigSeekStep,
    bool? enableKeyboard,
    bool? enableGestures,
    bool? enableFullscreen,
    bool? pauseWhenBackgrounded,
    bool? resumeWhenForegrounded,
    String? title,
    String? subtitle,
  }) {
    return PrysmVideoOptions(
      autoPlay: autoPlay ?? this.autoPlay,
      loop: loop ?? this.loop,
      muted: muted ?? this.muted,
      initialVolume: initialVolume ?? this.initialVolume,
      initialRate: initialRate ?? this.initialRate,
      fit: fit ?? this.fit,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      showControls: showControls ?? this.showControls,
      autoHideControls: autoHideControls ?? this.autoHideControls,
      controlsAutoHideDelay:
          controlsAutoHideDelay ?? this.controlsAutoHideDelay,
      seekStep: seekStep ?? this.seekStep,
      bigSeekStep: bigSeekStep ?? this.bigSeekStep,
      enableKeyboard: enableKeyboard ?? this.enableKeyboard,
      enableGestures: enableGestures ?? this.enableGestures,
      enableFullscreen: enableFullscreen ?? this.enableFullscreen,
      pauseWhenBackgrounded:
          pauseWhenBackgrounded ?? this.pauseWhenBackgrounded,
      resumeWhenForegrounded:
          resumeWhenForegrounded ?? this.resumeWhenForegrounded,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
    );
  }
}

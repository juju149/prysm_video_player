import '../data_source/prysm_video_source.dart';
import '../errors/prysm_video_error.dart';
import '../performance/prysm_performance_metrics.dart';
import '../tracks/prysm_tracks.dart';

enum PrysmPlaybackStatus {
  idle,
  opening,
  ready,
  playing,
  paused,
  buffering,
  ended,
  error,
}

class PrysmVideoState {
  const PrysmVideoState({
    this.status = PrysmPlaybackStatus.idle,
    this.source,
    this.playing = false,
    this.completed = false,
    this.buffering = false,
    this.live = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.volume = 100,
    this.speed = 1,
    this.muted = false,
    this.looping = false,
    this.fullscreen = false,
    this.pictureInPicture = false,
    this.controlsLocked = false,
    this.availableTracks = const PrysmAvailableTracks(),
    this.selectedTracks = const PrysmSelectedTracks(),
    this.availableQualities = const <PrysmVideoQuality>[
      PrysmVideoQuality.auto(),
    ],
    this.selectedQuality = const PrysmVideoQuality.auto(),
    this.error,
    this.metrics = const PrysmPerformanceMetrics(),
  });

  final PrysmPlaybackStatus status;
  final PrysmVideoSource? source;
  final bool playing;
  final bool completed;
  final bool buffering;
  final bool live;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final double volume;
  final double speed;
  final bool muted;
  final bool looping;
  final bool fullscreen;
  final bool pictureInPicture;
  final bool controlsLocked;
  final PrysmAvailableTracks availableTracks;
  final PrysmSelectedTracks selectedTracks;
  final List<PrysmVideoQuality> availableQualities;
  final PrysmVideoQuality selectedQuality;
  final PrysmVideoError? error;
  final PrysmPerformanceMetrics metrics;

  bool get ready =>
      status != PrysmPlaybackStatus.idle &&
      status != PrysmPlaybackStatus.opening;

  double get progress {
    if (duration <= Duration.zero) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  double get bufferProgress {
    if (duration <= Duration.zero) return 0;
    return (bufferedPosition.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  Duration get remaining {
    if (duration <= Duration.zero) return Duration.zero;
    final value = duration - position;
    return value.isNegative ? Duration.zero : value;
  }

  PrysmVideoState copyWith({
    PrysmPlaybackStatus? status,
    PrysmVideoSource? source,
    bool clearSource = false,
    bool? playing,
    bool? completed,
    bool? buffering,
    bool? live,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    double? volume,
    double? speed,
    bool? muted,
    bool? looping,
    bool? fullscreen,
    bool? pictureInPicture,
    bool? controlsLocked,
    PrysmAvailableTracks? availableTracks,
    PrysmSelectedTracks? selectedTracks,
    List<PrysmVideoQuality>? availableQualities,
    PrysmVideoQuality? selectedQuality,
    PrysmVideoError? error,
    bool clearError = false,
    PrysmPerformanceMetrics? metrics,
  }) {
    return PrysmVideoState(
      status: status ?? this.status,
      source: clearSource ? null : source ?? this.source,
      playing: playing ?? this.playing,
      completed: completed ?? this.completed,
      buffering: buffering ?? this.buffering,
      live: live ?? this.live,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      muted: muted ?? this.muted,
      looping: looping ?? this.looping,
      fullscreen: fullscreen ?? this.fullscreen,
      pictureInPicture: pictureInPicture ?? this.pictureInPicture,
      controlsLocked: controlsLocked ?? this.controlsLocked,
      availableTracks: availableTracks ?? this.availableTracks,
      selectedTracks: selectedTracks ?? this.selectedTracks,
      availableQualities: availableQualities ?? this.availableQualities,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      error: clearError ? null : error ?? this.error,
      metrics: metrics ?? this.metrics,
    );
  }
}

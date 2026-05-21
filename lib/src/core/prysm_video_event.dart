import '../errors/prysm_video_error.dart';

enum PrysmVideoEventType {
  playerInitialized,
  sourceOpened,
  playbackStarted,
  playbackPaused,
  playbackCompleted,
  seekStarted,
  seekCompleted,
  bufferingStarted,
  bufferingEnded,
  qualityChanged,
  subtitleChanged,
  audioTrackChanged,
  error,
  fullscreenEntered,
  fullscreenExited,
  pipEntered,
  pipExited,
  disposed,
}

class PrysmVideoEvent {
  PrysmVideoEvent({
    required this.type,
    this.position = Duration.zero,
    this.data = const <String, Object?>{},
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final PrysmVideoEventType type;
  final DateTime timestamp;
  final Duration position;
  final Map<String, Object?> data;
  final PrysmVideoError? error;
}

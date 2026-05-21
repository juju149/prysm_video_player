class PrysmPerformanceMetrics {
  const PrysmPerformanceMetrics({
    this.timeToFirstFrame,
    this.startupLatency,
    this.seekLatency,
    this.droppedFrames,
    this.bufferedDuration = Duration.zero,
    this.averageBitrate,
    this.playerMemoryEstimate,
    this.renderedFrames,
    this.playbackStalls = 0,
    this.rebufferCount = 0,
    this.rebufferDuration = Duration.zero,
  });

  final Duration? timeToFirstFrame;
  final Duration? startupLatency;
  final Duration? seekLatency;
  final int? droppedFrames;
  final Duration bufferedDuration;
  final int? averageBitrate;
  final int? playerMemoryEstimate;
  final int? renderedFrames;
  final int playbackStalls;
  final int rebufferCount;
  final Duration rebufferDuration;

  PrysmPerformanceMetrics copyWith({
    Duration? timeToFirstFrame,
    Duration? startupLatency,
    Duration? seekLatency,
    int? droppedFrames,
    Duration? bufferedDuration,
    int? averageBitrate,
    int? playerMemoryEstimate,
    int? renderedFrames,
    int? playbackStalls,
    int? rebufferCount,
    Duration? rebufferDuration,
  }) {
    return PrysmPerformanceMetrics(
      timeToFirstFrame: timeToFirstFrame ?? this.timeToFirstFrame,
      startupLatency: startupLatency ?? this.startupLatency,
      seekLatency: seekLatency ?? this.seekLatency,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      bufferedDuration: bufferedDuration ?? this.bufferedDuration,
      averageBitrate: averageBitrate ?? this.averageBitrate,
      playerMemoryEstimate: playerMemoryEstimate ?? this.playerMemoryEstimate,
      renderedFrames: renderedFrames ?? this.renderedFrames,
      playbackStalls: playbackStalls ?? this.playbackStalls,
      rebufferCount: rebufferCount ?? this.rebufferCount,
      rebufferDuration: rebufferDuration ?? this.rebufferDuration,
    );
  }
}

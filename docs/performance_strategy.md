# Performance Strategy

The player is designed to make performance measurable instead of promising it.

Implemented foundations:

- Lazy backend creation through the controller.
- Immutable `PrysmVideoState` and small widgets to limit rebuild scope.
- Position updates throttled by `PrysmVideoConfig.positionThrottle`.
- `RepaintBoundary` around the video surface.
- `PrysmPerformanceMetrics` for startup, seek, buffering and approximate backend metrics.
- Optional source preloading through `controller.preload`.

Benchmarks to run are listed in `benchmark/README.md`. Real conclusions must include device, OS, backend, codec, resolution, bitrate and network profile.

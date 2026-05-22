# Prysm video benchmarks

Use `doc/validation_matrix.md` as the source of truth for required platforms,
assets, metrics, and pass criteria.

Run these scenarios manually per target platform until automated harnesses are added:

- MP4 1080p startup time and time to first frame.
- HLS 1080p live and VOD buffering ratio.
- 4K playback on desktop and high-end mobile.
- Playlist of 20 short videos with next/previous navigation.
- Vertical feed with multiple controllers and controlled preloading.
- Intensive seek loop, measuring seek latency and stalls.
- Fullscreen enter/exit loop.
- Subtitles on/off with WebVTT and SRT.
- Slow network simulation using platform tooling or browser throttling.

Record `PrysmPerformanceMetrics` plus device, OS, codec, bitrate, and backend.

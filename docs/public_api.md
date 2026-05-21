# Public API

Minimal:

```dart
final controller = PrysmVideoController(
  source: PrysmVideoSource.network(
    url: 'https://example.com/movie.m3u8',
    title: 'Movie',
  ),
  config: const PrysmVideoConfig(autoPlay: true),
);

PrysmVideoPlayer(controller: controller);
```

Advanced:

```dart
PrysmVideoPlayer(
  controller: controller,
  theme: const PrysmVideoTheme.dark(),
  onEvent: analytics.track,
);
```

Headless:

```dart
PrysmVideoSurface(controller: controller);
```

Controller commands include `play`, `pause`, `seekTo`, `seekBy`, `setSpeed`, `setVolume`, `mute`, `unmute`, `selectSubtitleTrack`, `selectAudioTrack`, `selectVideoQuality`, `enterFullscreen`, `exitFullscreen`, `enablePictureInPicture`, `preload` and `dispose`.

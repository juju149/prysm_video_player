# Public API

The package is controller first. `PrysmVideoPlayer` renders a controller; it
does not own source or config directly.

## Minimal

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

## Advanced

```dart
PrysmVideoPlayer(
  controller: controller,
  theme: const PrysmVideoTheme.dark(),
  onEvent: analytics.track,
);
```

## Headless

```dart
PrysmVideoSurface(controller: controller);
```

## Custom Controls

```dart
PrysmVideoPlayer(
  controller: controller,
  controls: (context, controller, state) {
    return MyControls(controller: controller, state: state);
  },
);
```

## Controller Commands

Controller commands include `open`, `preload`, `play`, `pause`, `toggle`,
`stop`, `seekTo`, `seekBy`, `replay10`, `forward10`, `setSpeed`, `setVolume`,
`mute`, `unmute`, `toggleMute`, `setLooping`, `selectSubtitleTrack`,
`selectAudioTrack`, `selectVideoQuality`, `enterFullscreen`, `exitFullscreen`,
`enablePictureInPicture`, `setControlsLocked`, and `dispose`.

## Stability

The intended 1.0 stable API is tracked in `doc/api_1_0.md`. README examples,
tests, and examples must be updated in the same change as any public API change.

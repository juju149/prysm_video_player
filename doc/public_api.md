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

## Fine-Grained Customization

`PrysmVideoCustomization` can replace or wrap individual player regions while
leaving the default player layout intact.

Available slots:

- `controlsBuilder`
- `loadingBuilder`
- `errorBuilder`
- `progressBarBuilder`
- `settingsMenuBuilder`
- `speedPickerBuilder`
- `qualityPickerBuilder`
- `subtitlePickerBuilder`
- `audioPickerBuilder`
- `subtitleRendererBuilder`
- `topBarBuilder`
- `bottomBarBuilder`
- `gestureBuilder`
- `keyboardShortcutHandler`
- `tvFocusBuilder`

Builders that wrap existing UI receive the default widget as `details.child`.
Handlers receive `PrysmPlayerBuildContext`, which includes controller, state,
config, theme, platform, visibility, fullscreen callback, and thumbnails.

## Controller Commands

Controller commands include `open`, `preload`, `play`, `pause`, `toggle`,
`stop`, `seekTo`, `seekBy`, `replay10`, `forward10`, `setSpeed`, `setVolume`,
`mute`, `unmute`, `toggleMute`, `setLooping`, `selectSubtitleTrack`,
`selectAudioTrack`, `selectVideoQuality`, `enterFullscreen`, `exitFullscreen`,
`enablePictureInPicture`, `disablePictureInPicture`, `discoverCastDevices`,
`startCasting`, `stopCasting`, `setControlsLocked`, and `dispose`.

## Integration Adapters

```dart
final controller = PrysmVideoController(
  cache: createPrysmVideoCache(),
  drmAdapter: PrysmHttpDrmLicenseAdapter(),
  pictureInPicture: PrysmPlatformPictureInPictureAdapter(),
  mediaIntegration: PrysmPlatformMediaIntegration(),
  castAdapter: PrysmPlatformCastAdapter(),
);
```

Adapters are optional. Default implementations are no-op or platform-safe, so
apps can opt into native behavior only on the targets they support.

## Stability

The intended 1.0 stable API is tracked in `doc/api_1_0.md`. README examples,
tests, and examples must be updated in the same change as any public API change.

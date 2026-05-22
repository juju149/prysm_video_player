# prysm_video_player

A premium Flutter video player package built on top of `media_kit`.

The package is designed as a high-level player API for product apps: controller
first, responsive by default, customizable, and ready for mobile, desktop, web,
and TV-style interfaces.

## Features

- Cross-platform playback through `media_kit`
- Network, HLS, DASH, live, playlist, file, asset, blob, and memory sources
- HTTP headers and media metadata
- Responsive controls for phones, tablets, desktop, web, and TV layouts
- Keyboard shortcuts: space/K, arrows, M, F
- Mouse, touch, and remote-friendly controls
- Fullscreen route with immersive system UI
- Play/pause, seek, replay/forward, mute, volume, speed selection
- Buffer progress, loading indicator, error surfacing
- Loop, autoplay, initial volume, initial speed, aspect ratio, and fit options
- Theming through `PrysmVideoTheme`
- Controller-first API and headless rendering for advanced apps
- Custom controls through `PrysmVideoControlsBuilder`
- File cache for downloadable network/blob sources through `PrysmVideoCache`
- Optional adapters for PiP, media sessions, notifications, remote commands,
  background audio, DRM license requests, Chromecast, and AirPlay

## Install

```yaml
dependencies:
  prysm_video_player:
    path: ../prysm_video_player
```

If published later:

```yaml
dependencies:
  prysm_video_player: ^0.0.1
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:prysm_video_player/prysm_video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PrysmVideoKit.ensureInitialized();

  runApp(const MaterialApp(home: Demo()));
}

class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  late final PrysmVideoController controller;

  @override
  void initState() {
    super.initState();
    controller = PrysmVideoController(
      source: PrysmVideoSource.network(
        url: 'https://example.com/video.mp4',
        title: 'Big Buck Bunny',
        poster: 'https://example.com/poster.jpg',
      ),
      config: const PrysmVideoConfig(
        aspectRatio: 16 / 9,
        autoPlay: true,
        looping: false,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: PrysmVideoPlayer(
          controller: controller,
          theme: const PrysmVideoTheme.dark(),
        ),
      ),
    );
  }
}
```

## Advanced Controller Usage

```dart
final controller = PrysmVideoController(
  config: const PrysmVideoConfig(autoPlay: false),
);

await controller.open(PrysmVideoSource.asset('assets/trailer.mp4'));
await controller.setSpeed(1.25);
await controller.seekBy(const Duration(seconds: 30));
```

## Integration Adapters

```dart
final controller = PrysmVideoController(
  source: PrysmVideoSource.network(url: 'https://cdn.example.com/movie.mp4'),
  config: const PrysmVideoConfig(
    cache: PrysmCacheConfig(policy: PrysmCachePolicy.fullFile),
    enablePictureInPicture: true,
    enableMediaNotifications: true,
    enableBackgroundAudio: true,
  ),
  cache: createPrysmVideoCache(),
  pictureInPicture: PrysmPlatformPictureInPictureAdapter(),
  mediaIntegration: PrysmPlatformMediaIntegration(),
  drmAdapter: PrysmHttpDrmLicenseAdapter(),
  castAdapter: PrysmPlatformCastAdapter(),
);
```

Platform adapters use stable Dart APIs and method-channel boundaries. Host apps
or future federated implementations can provide native handlers without changing
the public player API.

## Custom Controls

```dart
PrysmVideoPlayer(
  controller: controller,
  controls: (context, controller, state) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: TextButton(
        onPressed: controller.toggle,
        child: Text(state.playing ? 'Pause' : 'Play'),
      ),
    );
  },
);
```

## Source Types

```dart
PrysmVideoSource.network(url: 'https://cdn.example.com/movie.mp4');
PrysmVideoSource.network(url: 'https://cdn.example.com/vod.m3u8');
PrysmVideoSource.network(url: 'https://cdn.example.com/manifest.mpd');
PrysmVideoSource.live(url: 'https://cdn.example.com/live.m3u8');
PrysmVideoSource.file('/storage/emulated/0/movie.mkv');
PrysmVideoSource.asset('assets/intro.mp4');
PrysmVideoSource.memory(bytes, mimeType: 'video/mp4');
PrysmVideoSource.playlist([sourceA, sourceB]);
```

## Platform Notes

`media_kit` supports Android, iOS, macOS, Windows, Linux, and web. Real codec
support still depends on platform capabilities, browser policies, DRM, CORS,
and how the host app is packaged.

For Android release builds, prefer app bundles or split per ABI to keep native
video libraries efficient.

See `doc/platform_support.md` and `doc/validation_matrix.md` before claiming
support for a production target.

## Stability

The intended 1.0 public surface is documented in `doc/api_1_0.md`. Breaking
changes to controller, source, config, theme, event, error, backend, and
customization APIs should be avoided unless the package intentionally moves to a
new major version.

## Roadmap

- Playlist drawer
- Chromecast/AirPlay adapters
- Native PiP integrations
- DRM backends
- Cache/offline adapters
- Analytics hooks
- TV focus traversal polish

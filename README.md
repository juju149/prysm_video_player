# prysm_video_player

A premium Flutter video player package built on top of `media_kit`.

The package is designed as a high-level player API for product apps: simple to
embed, responsive by default, and ready for mobile, desktop, web, and TV-style
interfaces.

## Features

- Cross-platform playback through `media_kit`
- Network, URI, file, asset, and memory sources
- HTTP headers and media metadata
- Responsive controls for phones, tablets, desktop, web, and TV layouts
- Keyboard shortcuts: space/K, arrows, M, F
- Mouse, touch, and remote-friendly controls
- Fullscreen route with immersive system UI
- Play/pause, seek, replay/forward, mute, volume, speed selection
- Buffer progress, loading indicator, error surfacing
- Loop, autoplay, initial volume, initial speed, aspect ratio, and fit options
- Theming through `PrysmVideoTheme`
- Controller-first API for advanced apps

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

class Demo extends StatelessWidget {
  const Demo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: PrysmVideoPlayer(
          source: PrysmVideoSource.network(
            'https://example.com/video.mp4',
            title: 'Big Buck Bunny',
            poster: 'https://example.com/poster.jpg',
          ),
          options: const PrysmVideoOptions(
            aspectRatio: 16 / 9,
            autoPlay: true,
            loop: false,
            title: 'Big Buck Bunny',
            subtitle: 'Demo stream',
          ),
        ),
      ),
    );
  }
}
```

## Advanced Controller Usage

```dart
final controller = PrysmVideoController(
  options: const PrysmVideoOptions(autoPlay: false),
);

await controller.open(PrysmVideoSource.asset('assets/trailer.mp4'));
await controller.setRate(1.25);
await controller.seekRelative(const Duration(seconds: 30));
```

## Source Types

```dart
PrysmVideoSource.network('https://cdn.example.com/live.m3u8');
PrysmVideoSource.uri('rtsp://example.com/live');
PrysmVideoSource.file('/storage/emulated/0/movie.mkv');
PrysmVideoSource.asset('assets/intro.mp4');
PrysmVideoSource.memory(bytes, mimeType: 'video/mp4');
```

## Platform Notes

`media_kit` supports Android, iOS, macOS, Windows, Linux, and web. Real codec
support still depends on platform capabilities, browser policies, DRM, CORS,
and how the host app is packaged.

For Android release builds, prefer app bundles or split per ABI to keep native
video libraries efficient.

## Roadmap

- Audio/subtitle track picker UI
- Playlist drawer
- Thumbnail preview scrubbing
- Chromecast/AirPlay adapters
- DRM adapter interfaces
- Analytics hooks
- TV focus traversal polish

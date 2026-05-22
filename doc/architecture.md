# Architecture

`prysm_video_player` is layered so the UI is replaceable and the playback backend is not hardcoded into the public API.

Layers:

- Public API: `PrysmVideoPlayer`, `PrysmVideoSurface`, `PrysmVideoController`, sources, config, theme, events and errors.
- Controller: owns immutable `PrysmVideoState`, emits `PrysmVideoEvent`, guards disposal, throttles position updates and maps backend errors.
- Playback backend: `PrysmPlaybackBackend` abstracts the engine. `MediaKitPlaybackBackend` is the default implementation.
- Data sources: `PrysmVideoSource` models network, HLS, DASH, file, asset, blob, live, playlist and multi-quality sources.
- UI: `PrysmVideoSurface` is headless video rendering. `PrysmVideoPlayer` composes surface plus default premium controls. Custom controls can replace all UI.
- Integration layers: `cache`, `drm`, `pip`, `media`, and `casting` expose separated extension points. The default cache stores downloadable files on IO platforms; native/device features are adapter driven.
- Platform layers: `desktop`, `tv`, `web` and `fullscreen` keep UI and platform policy isolated.

The package does not impose Riverpod, Bloc or Provider. State is available through `ChangeNotifier` and event hooks.

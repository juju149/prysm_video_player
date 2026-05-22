## 0.0.1

- Initial package scaffold.
- Added `PrysmVideoPlayer`, `PrysmVideoController`, source models, options, and theme API.
- Added responsive playback controls, fullscreen, keyboard shortcuts, speed, volume, seeking, buffering, and errors.
- Added package CI for analyze, tests, and pub publish dry-run.
- Documented the intended API 1.0 stability contract and validation matrix.
- Aligned README examples with the controller-first API.
- Added file cache infrastructure for downloadable network/blob sources.
- Added PiP, media session, remote command, background audio, notification, DRM, and casting adapter contracts.
- Added controller events and tests for cache resolution, PiP, remote commands, and casting.
- Added `PrysmVideoCustomization` with granular builders for loading, errors, controls, progress, settings, track pickers, subtitles, bars, gestures, keyboard shortcuts, and TV focus.
- Split progress and settings/picker UI internals out of the main player widget for maintainability.
- Added `PrysmVideoSurfaceBuilder` for alternate render surfaces, previews, fullscreen reuse, and engine-free widget tests.
- Expanded widget tests for loading, error retry, custom progress, settings/pickers, keyboard overrides, gesture wrappers, and TV focus.
- Replaced the integration placeholder with smoke coverage for opening sources, play/pause, seek, source errors, fullscreen routes, and controller disposal.
- Expanded the example app to demonstrate fine-grained customization, cache, subtitles, quality/audio pickers, analytics events, platform/no-op adapters, and TV theme mode.

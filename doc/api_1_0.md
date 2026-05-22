# API 1.0 Stability Contract

This document defines the public surface that should remain stable until the
package intentionally moves to a new major version.

## Stable Public Entry Points

- `PrysmVideoKit.ensureInitialized`
- `PrysmVideoController`
- `PrysmVideoPlayer`
- `PrysmVideoSurface`
- `PrysmVideoSource`
- `PrysmVideoConfig`
- `PrysmVideoTheme`
- `PrysmVideoState`
- `PrysmVideoEvent`
- `PrysmVideoError`
- `PrysmVideoCustomization`
- `PrysmPlaybackBackend`
- `MediaKitPlaybackBackend`
- track, subtitle, thumbnail, cache, DRM, PiP, web policy, and TV focus models

## Controller Contract

`PrysmVideoController` is the owner of playback state and commands. The 1.0
contract includes:

- `state`, `snapshot`, `events`, `videoController`, and `isDisposed`
- source lifecycle: `open`, `preload`, `stop`, `dispose`
- playback: `play`, `pause`, `toggle`
- seeking: `seekTo`, `seekBy`, `replay10`, `forward10`
- media settings: `setSpeed`, `setVolume`, `mute`, `unmute`, `toggleMute`,
  `setLooping`
- track and quality selection: `selectSubtitleTrack`, `selectAudioTrack`,
  `selectVideoQuality`
- presentation state: `enterFullscreen`, `exitFullscreen`,
  `enablePictureInPicture`, `disablePictureInPicture`, `setControlsLocked`
- casting: `discoverCastDevices`, `startCasting`, `stopCasting`

Breaking changes to method names, parameter semantics, event ordering, disposal
guards, or state fields require a major version.

## Configuration Contract

`PrysmVideoConfig` is immutable and constructor based. New fields may be added
with conservative defaults, but existing fields should not be renamed or changed
semantically:

- playback defaults: autoplay, looping, start position, quality, volume, speed
- timing: tick interval, position throttle, seek steps
- layout: fit and aspect ratio
- controls: visibility, auto-hide, gestures, keyboard, TV controls
- platform behavior: fullscreen, PiP, background pause/resume
- background audio and media notification opt-ins
- cache policy

## Source Contract

`PrysmVideoSource` must continue to support:

- `network`
- `live`
- `file`
- `asset`
- `memory`
- `blob`
- `playlist`
- `multiQuality`

The `toMedia` mapping must preserve headers, metadata, start/end ranges, selected
quality, subtitles, DRM metadata, and protected source signaling.

## UI Customization Contract

The stable customization slots are:

- whole-controls replacement through `PrysmVideoControlsBuilder`
- fine-grained UI replacement through `PrysmVideoCustomization`
- headless rendering through `PrysmVideoSurface`
- theme replacement through `PrysmVideoTheme`
- labels through `PrysmVideoLabels`
- subtitle visual styling through `PrysmSubtitleStyle`
- thumbnail preview configuration through `PrysmThumbnailConfig`
- event bridge through `PrysmVideoPlayer.onEvent`
- backend replacement through `PrysmPlaybackBackend`
- cache replacement through `PrysmVideoCache`
- DRM preparation and license requests through `PrysmDrmAdapter`
- PiP through `PrysmPictureInPictureAdapter`
- media sessions, notifications, background audio, and remote commands through
  `PrysmMediaIntegration`
- Chromecast, AirPlay, DLNA, or proprietary casting through `PrysmCastAdapter`

The fine-grained 1.0 customization surface includes loading, error, controls
overlay, progress bar, settings menu, speed picker, quality picker, subtitle
picker, audio picker, subtitle renderer, top bar, bottom bar, gesture wrapper,
keyboard shortcut handler, and TV focus builder.

Future granular slots such as top bar, bottom bar, progress bar, settings menu,
loading overlay, and error overlay should be additive. Existing users must be
able to keep replacing the entire controls layer.

## Event And Error Contract

`PrysmVideoEventType`, `PrysmVideoEvent`, `PrysmVideoErrorKind`, and
`PrysmVideoError` are part of the stable integration surface. Analytics and
host apps may rely on them.

New event or error kinds may be added. Existing names and retryability semantics
should not change in a minor release.

## Backend Contract

`PrysmPlaybackBackend` is the extension point for alternate engines. The default
backend remains `MediaKitPlaybackBackend`.

Any native DRM, PiP, cache, or casting work should be added through optional
adapters or backend capabilities without making `media_kit` implementation
details leak into the high-level API.

## Breaking Change Rules

- Do not remove public exports without a replacement and migration path.
- Do not rename public classes, methods, enum values, or constructor parameters
  in a minor release.
- Do not change default behavior silently.
- Prefer additive config fields and optional callbacks.
- Mark migrations with `@Deprecated` for at least one minor release before
  removal.
- Keep README, `doc/public_api.md`, examples, tests, and changelog in sync with
  any public API change.

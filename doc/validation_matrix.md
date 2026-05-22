# Validation Matrix

This matrix defines the minimum proof required before claiming production-grade
support for a platform.

## Platforms

| Target | Required devices | Browsers / shells | Status gate |
| --- | --- | --- | --- |
| Android phone | Low-end, mid-range, flagship | Native Flutter app | Required before mobile stable |
| Android tablet | 10 inch tablet | Native Flutter app | Required before tablet stable |
| Android TV | Physical TV or certified box | Native Flutter app | Required before TV stable |
| iOS | Current iPhone plus one older supported iPhone | Native Flutter app | Required before iOS stable |
| iPadOS | Current iPad | Native Flutter app | Required before tablet stable |
| Web Chrome | Desktop Chrome and Android Chrome | Browser | Required before web stable |
| Web Safari | macOS Safari and iOS Safari | Browser | Required before web stable |
| Windows | Windows 10 and 11 | Native Flutter app | Required before desktop stable |
| macOS | Intel or Apple Silicon plus current macOS | Native Flutter app | Required before desktop stable |
| Linux | Ubuntu LTS | Native Flutter app | Required before desktop stable |

## Media Coverage

| Scenario | Assets | Required observations |
| --- | --- | --- |
| MP4 VOD | H264/AAC 720p, 1080p, 4K | startup, seek, pause/resume, fullscreen |
| HLS VOD | H264 ladder, subtitles, audio tracks | ABR behavior, track selection, buffering |
| HLS live | live and live with DVR window | latency, seekable range, reconnect |
| DASH VOD | H264 and VP9 ladders | manifest load, quality selection |
| Web codecs | H264, VP9, AV1 where supported | browser compatibility and graceful errors |
| Subtitles | SRT, WebVTT, embedded, external URL | rendering, switching, off state |
| Audio tracks | stereo, 5.1, alternate language | switching and label accuracy |
| Playlist | 20 short videos | next item startup, memory cleanup |
| Multi-quality source | explicit MP4 variants | position preservation on quality switch |
| Protected source | signed URL or auth headers | no accidental cache, error mapping |

## Metrics To Record

Every run must capture:

- package version and git commit
- Flutter version and Dart version
- OS, device model, CPU/GPU, memory class, browser version if web
- backend and native library versions
- source type, codec, resolution, bitrate, duration, live/VOD
- startup latency and time to first frame
- seek latency at 10%, 50%, 90%
- rebuffer count and total rebuffer duration
- dropped frames and rendered frames when available
- average CPU, peak CPU, average memory, peak memory
- battery drain for 30 minute mobile and TV playback
- network profile: Wi-Fi, cellular, throttled, offline transition
- error kind and user-facing message for failure cases

## Pass Criteria

| Area | Minimum bar |
| --- | --- |
| Startup | 1080p VOD starts consistently without UI lockups |
| Seeking | seek completes and state remains consistent after repeated seeks |
| Smoothness | no persistent frame drops on supported codecs and bitrates |
| Memory | repeated open/dispose and playlists do not grow unbounded |
| Errors | unsupported codecs, CORS, 401/403, offline, and invalid URLs map to useful errors |
| Controls | touch, mouse, keyboard, and D-pad interactions do not conflict |
| Accessibility | controls have readable labels and focus traversal works on TV/desktop |
| Fullscreen | enter/exit loops do not lose playback state |
| Background | configured pause/resume behavior matches platform expectations |
| Web | autoplay, CORS, custom headers, and codec limits are documented per browser |

## Manual Run Template

```text
Date:
Tester:
Commit:
Flutter:
Platform:
Device / browser:
Backend:
Source:
Codec / resolution / bitrate:
Network:

Startup latency:
Time to first frame:
Seek latency p50 / p95:
Rebuffer count / duration:
Dropped frames:
Average / peak CPU:
Average / peak memory:
Battery delta:

Passed:
Failures:
Notes:
Artifacts:
```

## Automation Plan

- CI always runs `flutter analyze`, `flutter test`, and
  `flutter pub publish --dry-run`.
- Widget tests cover controller state, errors, theme, source modeling, controls,
  and focus behavior.
- Integration tests should replace the current placeholder with real playback
  smoke tests for at least network MP4, HLS VOD, seek, pause/resume, and
  fullscreen.
- Device labs or release checklists own platform-specific runs that GitHub
  Actions cannot reliably execute.

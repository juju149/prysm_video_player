# Dependencies

Runtime:

- `flutter`: required SDK for widgets, platform input, semantics and rendering.
- `crypto`: stable cache keys for local media files.
- `http`: file cache downloads and DRM license helper requests.
- `media_kit`: maintained playback engine used as the default backend.
- `media_kit_video`: Flutter video surface for `media_kit`.
- `media_kit_libs_video`: native video libraries for desktop/mobile targets supported by `media_kit`.
- `path_provider`: application cache directory lookup for file caching.

Development:

- `flutter_test`: unit and widget tests.
- `flutter_lints`: standard static analysis rules.

No analytics, cast vendor SDK, DRM CDM SDK or native media-session SDK is bundled. Those integrations should remain opt-in because they have product, legal and platform consequences.

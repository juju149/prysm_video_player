# Known Limits

- DRM has a license adapter contract and HTTP license helper. Real Widevine, FairPlay and PlayReady playback still needs a platform backend/CDM path and device validation.
- PiP has an adapter contract and platform-channel adapter. Native handlers must be provided per host app or federated platform implementation.
- Cache is implemented for downloadable network/blob files. Adaptive HLS/DASH segment caching and encrypted/offline license workflows are not implemented.
- Protected or signed video sources are never cached by default.
- Media sessions, notifications, remote controls, background audio, Chromecast and AirPlay are adapter based. The package exposes stable hooks but does not bundle vendor SDKs.
- Web custom headers, CORS, autoplay and codec support are browser constrained.
- tvOS is documented as experimental because Flutter does not officially support it.
- Quality switching is best for explicit multi-quality sources. Backend track quality switching depends on what `media_kit` exposes for the stream.
- Memory metrics are approximate until platform-specific probes are added.

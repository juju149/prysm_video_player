# Known Limits

- DRM is modeled but not fully implemented. Widevine, FairPlay and PlayReady need platform-specific license handling and must be validated per storefront/device.
- PiP is an API placeholder in this MVP. Native support differs strongly between platforms.
- Cache is disabled by default. Protected or signed video sources are never cached by default.
- Web custom headers, CORS, autoplay and codec support are browser constrained.
- tvOS is documented as experimental because Flutter does not officially support it.
- Quality switching is best for explicit multi-quality sources. Backend track quality switching depends on what `media_kit` exposes for the stream.
- Memory metrics are approximate until platform-specific probes are added.

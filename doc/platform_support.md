# Platform Support

This table documents implementation status. Production support must be backed
by the validation matrix in `doc/validation_matrix.md`.

| Platform | Playback | Fullscreen | PiP | Media session / cast | Subtitles | Audio tracks | Quality selection | Cache | DRM | Limitations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Android | media_kit | Flutter route + system UI | Adapter hook | Adapter hook | External and embedded when backend exposes them | Backend exposed | Backend tracks or source variants | File cache for downloadable sources | License adapter + native backend required | DRM requires native work and license integration |
| iOS | media_kit | Flutter route + system UI | Adapter hook | Adapter hook | External and embedded when backend exposes them | Backend exposed | Backend tracks or source variants | File cache for downloadable sources | License adapter + native backend required | FairPlay needs a native backend path |
| Web | media_kit web | Browser/backend limits | Browser dependent adapter | Browser/adapter constrained | External URI/data where backend supports it | Limited | Limited | Browser cache only | Not implemented | Autoplay, CORS, codecs and headers are browser constrained |
| Windows | media_kit | Flutter route | Unsupported by default | Adapter hook | Supported by backend | Supported by backend | Supported by backend | File cache for downloadable sources | License adapter + native backend required | Codec availability depends on backend binaries |
| macOS | media_kit | Flutter route | Adapter hook | Adapter hook | Supported by backend | Supported by backend | Supported by backend | File cache for downloadable sources | License adapter + native backend required | Native PiP needs separate integration |
| Linux | media_kit | Flutter route | Unsupported by default | Adapter hook | Supported by backend | Supported by backend | Supported by backend | File cache for downloadable sources | License adapter + native backend required | Desktop codecs vary by environment |
| Android TV | media_kit | Flutter route | Unsupported by default | Adapter hook | Supported by backend | Supported by backend | Supported by backend | File cache for downloadable sources | License adapter + native backend required | D-pad UX is included; store/device testing still required |
| tvOS | Experimental strategy | Not guaranteed | Adapter hook only | Adapter hook only | Not guaranteed | Not guaranteed | Not guaranteed | Not guaranteed | Native required | Flutter tvOS is not officially supported |

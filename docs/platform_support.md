# Platform Support

| Platform | Playback | Fullscreen | PiP | Subtitles | Audio tracks | Quality selection | Cache | DRM | Limitations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Android | media_kit | Flutter route + system UI | API placeholder | External and embedded when backend exposes them | Backend exposed | Backend tracks or source variants | Strategy only | Architecture only | DRM requires native work and license integration |
| iOS | media_kit | Flutter route + system UI | API placeholder | External and embedded when backend exposes them | Backend exposed | Backend tracks or source variants | Strategy only | Architecture only | FairPlay needs a native backend path |
| Web | media_kit web | Browser/backend limits | Browser dependent | External URI/data where backend supports it | Limited | Limited | Browser cache only | Not implemented | Autoplay, CORS, codecs and headers are browser constrained |
| Windows | media_kit | Flutter route | Unsupported by default | Supported by backend | Supported by backend | Supported by backend | Strategy only | Architecture only | Codec availability depends on backend binaries |
| macOS | media_kit | Flutter route | Unsupported by default | Supported by backend | Supported by backend | Supported by backend | Strategy only | Architecture only | Native PiP needs separate integration |
| Linux | media_kit | Flutter route | Unsupported by default | Supported by backend | Supported by backend | Supported by backend | Strategy only | Architecture only | Desktop codecs vary by environment |
| Android TV | media_kit | Flutter route | Unsupported by default | Supported by backend | Supported by backend | Supported by backend | Strategy only | Architecture only | D-pad UX is included; store/device testing still required |
| tvOS | Experimental strategy | Not guaranteed | Not guaranteed | Not guaranteed | Not guaranteed | Not guaranteed | Strategy only | Native required | Flutter tvOS is not officially supported |

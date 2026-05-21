enum PrysmDrmScheme { widevine, fairPlay, playReady, clearKey }

class PrysmDrmConfig {
  const PrysmDrmConfig({
    required this.scheme,
    required this.licenseUrl,
    this.headers = const <String, String>{},
    this.certificateUrl,
    this.token,
  });

  final PrysmDrmScheme scheme;
  final String licenseUrl;
  final Map<String, String> headers;
  final String? certificateUrl;
  final String? token;
}

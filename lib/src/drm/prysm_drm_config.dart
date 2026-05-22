import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

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

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'scheme': scheme.name,
      'licenseUrl': licenseUrl,
      'headers': headers,
      'certificateUrl': certificateUrl,
      'token': token,
    };
  }
}

class PrysmDrmLicenseRequest {
  const PrysmDrmLicenseRequest({
    required this.config,
    required this.challenge,
    this.contentId,
  });

  final PrysmDrmConfig config;
  final Uint8List challenge;
  final String? contentId;
}

class PrysmDrmLicenseResponse {
  const PrysmDrmLicenseResponse({required this.bytes, this.contentType});

  final Uint8List bytes;
  final String? contentType;
}

abstract interface class PrysmDrmAdapter {
  Future<Map<String, Object?>> prepare(PrysmDrmConfig config);

  Future<PrysmDrmLicenseResponse> requestLicense(
    PrysmDrmLicenseRequest request,
  );
}

class PrysmNoopDrmAdapter implements PrysmDrmAdapter {
  const PrysmNoopDrmAdapter();

  @override
  Future<Map<String, Object?>> prepare(PrysmDrmConfig config) async {
    return config.toJson();
  }

  @override
  Future<PrysmDrmLicenseResponse> requestLicense(
    PrysmDrmLicenseRequest request,
  ) async {
    throw UnsupportedError(
      'No DRM license adapter is configured for ${request.config.scheme.name}.',
    );
  }
}

class PrysmHttpDrmLicenseAdapter implements PrysmDrmAdapter {
  PrysmHttpDrmLicenseAdapter({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Map<String, Object?>> prepare(PrysmDrmConfig config) async {
    final prepared = config.toJson();
    if (config.certificateUrl != null) {
      final certificate = await _client.get(
        Uri.parse(config.certificateUrl!),
        headers: config.headers,
      );
      if (certificate.statusCode < 200 || certificate.statusCode >= 300) {
        throw StateError(
          'DRM certificate request failed with HTTP ${certificate.statusCode}.',
        );
      }
      prepared['certificateBase64'] = base64Encode(certificate.bodyBytes);
    }
    return prepared;
  }

  @override
  Future<PrysmDrmLicenseResponse> requestLicense(
    PrysmDrmLicenseRequest request,
  ) async {
    final headers = <String, String>{
      ...request.config.headers,
      if (request.config.token != null) 'Authorization': request.config.token!,
    };
    final response = await _client.post(
      Uri.parse(request.config.licenseUrl),
      headers: headers,
      body: request.challenge,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'DRM license request failed with HTTP ${response.statusCode}.',
      );
    }
    return PrysmDrmLicenseResponse(
      bytes: response.bodyBytes,
      contentType: response.headers['content-type'],
    );
  }
}

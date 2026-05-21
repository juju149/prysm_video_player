import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';

enum PrysmVideoSourceType { uri, network, file, asset, memory }

class PrysmVideoSource {
  const PrysmVideoSource._({
    required this.type,
    required this.resource,
    this.bytes,
    this.mimeType,
    this.title,
    this.poster,
    this.httpHeaders,
    this.extras,
    this.start,
    this.end,
  });

  factory PrysmVideoSource.uri(
    String uri, {
    String? title,
    String? poster,
    Map<String, String>? httpHeaders,
    Map<String, dynamic>? extras,
    Duration? start,
    Duration? end,
  }) {
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.uri,
      resource: uri,
      title: title,
      poster: poster,
      httpHeaders: httpHeaders,
      extras: extras,
      start: start,
      end: end,
    );
  }

  factory PrysmVideoSource.network(
    String url, {
    String? title,
    String? poster,
    Map<String, String>? httpHeaders,
    Map<String, dynamic>? extras,
    Duration? start,
    Duration? end,
  }) {
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.network,
      resource: url,
      title: title,
      poster: poster,
      httpHeaders: httpHeaders,
      extras: extras,
      start: start,
      end: end,
    );
  }

  factory PrysmVideoSource.file(
    String path, {
    String? title,
    String? poster,
    Map<String, dynamic>? extras,
    Duration? start,
    Duration? end,
  }) {
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.file,
      resource: path,
      title: title,
      poster: poster,
      extras: extras,
      start: start,
      end: end,
    );
  }

  factory PrysmVideoSource.asset(
    String path, {
    String? title,
    String? poster,
    Map<String, dynamic>? extras,
    Duration? start,
    Duration? end,
  }) {
    final normalized = path.startsWith('asset:///') ? path : 'asset:///$path';
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.asset,
      resource: normalized,
      title: title,
      poster: poster,
      extras: extras,
      start: start,
      end: end,
    );
  }

  factory PrysmVideoSource.memory(
    Uint8List bytes, {
    String? mimeType,
    String? title,
    String? poster,
    Map<String, dynamic>? extras,
  }) {
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.memory,
      resource: 'memory',
      bytes: bytes,
      mimeType: mimeType,
      title: title,
      poster: poster,
      extras: extras,
    );
  }

  final PrysmVideoSourceType type;
  final String resource;
  final Uint8List? bytes;
  final String? mimeType;
  final String? title;
  final String? poster;
  final Map<String, String>? httpHeaders;
  final Map<String, dynamic>? extras;
  final Duration? start;
  final Duration? end;

  Future<Media> toMedia() async {
    if (type == PrysmVideoSourceType.memory) {
      final data = bytes;
      if (data == null) {
        throw StateError('Memory video source requires bytes.');
      }
      return Media.memory(data, type: mimeType);
    }

    return Media(
      resource,
      httpHeaders: httpHeaders,
      extras: {
        ...?extras,
        if (title != null) 'title': title,
        if (poster != null) 'poster': poster,
      },
      start: start,
      end: end,
    );
  }
}

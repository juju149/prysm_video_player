import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';

import '../drm/prysm_drm_config.dart';
import '../subtitles/prysm_subtitles.dart';
import '../tracks/prysm_tracks.dart';

enum PrysmVideoSourceType {
  network,
  hls,
  dash,
  file,
  asset,
  memory,
  blob,
  live,
  playlist,
  multiQuality,
}

class PrysmVideoSource {
  const PrysmVideoSource._({
    required this.type,
    required this.uri,
    this.items = const <PrysmVideoSource>[],
    this.qualities = const <PrysmVideoQuality>[],
    this.bytes,
    this.mimeType,
    this.headers = const <String, String>{},
    this.title,
    this.subtitle,
    this.poster,
    this.start,
    this.end,
    this.externalSubtitles = const <PrysmSubtitleTrack>[],
    this.drm,
    this.extras = const <String, Object?>{},
    this.protected = false,
  });

  factory PrysmVideoSource.network({
    required String url,
    Map<String, String> headers = const <String, String>{},
    String? title,
    String? subtitle,
    String? poster,
    Duration? start,
    Duration? end,
    List<PrysmSubtitleTrack> subtitles = const <PrysmSubtitleTrack>[],
    PrysmDrmConfig? drm,
    Map<String, Object?> extras = const <String, Object?>{},
    bool protected = false,
  }) {
    return PrysmVideoSource._(
      type: _inferNetworkType(url),
      uri: url,
      headers: headers,
      title: title,
      subtitle: subtitle,
      poster: poster,
      start: start,
      end: end,
      externalSubtitles: subtitles,
      drm: drm,
      extras: extras,
      protected: protected || drm != null || headers.isNotEmpty,
    );
  }

  factory PrysmVideoSource.live({
    required String url,
    Map<String, String> headers = const <String, String>{},
    String? title,
    String? poster,
    List<PrysmSubtitleTrack> subtitles = const <PrysmSubtitleTrack>[],
    PrysmDrmConfig? drm,
  }) {
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.live,
      uri: url,
      headers: headers,
      title: title,
      poster: poster,
      externalSubtitles: subtitles,
      drm: drm,
      protected: drm != null || headers.isNotEmpty,
    );
  }

  factory PrysmVideoSource.file(
    String path, {
    String? title,
    String? subtitle,
    String? poster,
    Duration? start,
    Duration? end,
    List<PrysmSubtitleTrack> subtitles = const <PrysmSubtitleTrack>[],
  }) {
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.file,
      uri: path,
      title: title,
      subtitle: subtitle,
      poster: poster,
      start: start,
      end: end,
      externalSubtitles: subtitles,
    );
  }

  factory PrysmVideoSource.asset(
    String assetPath, {
    String? title,
    String? subtitle,
    String? poster,
    Duration? start,
    Duration? end,
    List<PrysmSubtitleTrack> subtitles = const <PrysmSubtitleTrack>[],
  }) {
    final normalized = assetPath.startsWith('asset:///')
        ? assetPath
        : 'asset:///$assetPath';
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.asset,
      uri: normalized,
      title: title,
      subtitle: subtitle,
      poster: poster,
      start: start,
      end: end,
      externalSubtitles: subtitles,
    );
  }

  factory PrysmVideoSource.memory(
    Uint8List bytes, {
    String? mimeType,
    String? title,
    String? poster,
  }) {
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.memory,
      uri: 'memory://${identityHashCode(bytes)}',
      bytes: bytes,
      mimeType: mimeType,
      title: title,
      poster: poster,
    );
  }

  factory PrysmVideoSource.blob({
    required String url,
    String? mimeType,
    String? title,
    String? poster,
  }) {
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.blob,
      uri: url,
      mimeType: mimeType,
      title: title,
      poster: poster,
    );
  }

  factory PrysmVideoSource.playlist(
    List<PrysmVideoSource> items, {
    String? title,
    String? poster,
  }) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'Playlist cannot be empty.');
    }
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.playlist,
      uri: items.first.uri,
      items: List.unmodifiable(items),
      title: title,
      poster: poster,
    );
  }

  factory PrysmVideoSource.multiQuality({
    required List<PrysmVideoQuality> qualities,
    String? title,
    String? poster,
    Map<String, String> headers = const <String, String>{},
    List<PrysmSubtitleTrack> subtitles = const <PrysmSubtitleTrack>[],
  }) {
    if (qualities.isEmpty) {
      throw ArgumentError.value(
        qualities,
        'qualities',
        'At least one quality variant is required.',
      );
    }
    final first = qualities.firstWhere(
      (quality) => quality.url != null,
      orElse: () => qualities.first,
    );
    return PrysmVideoSource._(
      type: PrysmVideoSourceType.multiQuality,
      uri: first.url ?? '',
      qualities: List.unmodifiable([
        const PrysmVideoQuality.auto(),
        ...qualities,
      ]),
      headers: headers,
      title: title,
      poster: poster,
      externalSubtitles: subtitles,
      protected: headers.isNotEmpty,
    );
  }

  final PrysmVideoSourceType type;
  final String uri;
  final List<PrysmVideoSource> items;
  final List<PrysmVideoQuality> qualities;
  final Uint8List? bytes;
  final String? mimeType;
  final Map<String, String> headers;
  final String? title;
  final String? subtitle;
  final String? poster;
  final Duration? start;
  final Duration? end;
  final List<PrysmSubtitleTrack> externalSubtitles;
  final PrysmDrmConfig? drm;
  final Map<String, Object?> extras;
  final bool protected;

  bool get isLive => type == PrysmVideoSourceType.live;
  bool get isPlaylist => type == PrysmVideoSourceType.playlist;
  bool get isMultiQuality => type == PrysmVideoSourceType.multiQuality;
  bool get isAdaptiveStream =>
      type == PrysmVideoSourceType.hls || type == PrysmVideoSourceType.dash;

  PrysmVideoSource asCachedFile(String path) {
    return PrysmVideoSource.file(
      path,
      title: title,
      subtitle: subtitle,
      poster: poster,
      start: start,
      end: end,
      subtitles: externalSubtitles,
    );
  }

  PrysmVideoSource copyWith({
    PrysmVideoSourceType? type,
    String? uri,
    List<PrysmVideoSource>? items,
    List<PrysmVideoQuality>? qualities,
    Uint8List? bytes,
    String? mimeType,
    Map<String, String>? headers,
    String? title,
    String? subtitle,
    String? poster,
    Duration? start,
    Duration? end,
    List<PrysmSubtitleTrack>? externalSubtitles,
    PrysmDrmConfig? drm,
    Map<String, Object?>? extras,
    bool? protected,
  }) {
    return PrysmVideoSource._(
      type: type ?? this.type,
      uri: uri ?? this.uri,
      items: items ?? this.items,
      qualities: qualities ?? this.qualities,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType ?? this.mimeType,
      headers: headers ?? this.headers,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      poster: poster ?? this.poster,
      start: start ?? this.start,
      end: end ?? this.end,
      externalSubtitles: externalSubtitles ?? this.externalSubtitles,
      drm: drm ?? this.drm,
      extras: extras ?? this.extras,
      protected: protected ?? this.protected,
    );
  }

  Future<Media> toMedia({PrysmVideoQuality? quality}) async {
    if (type == PrysmVideoSourceType.memory) {
      final data = bytes;
      if (data == null) {
        throw StateError('Memory video source requires bytes.');
      }
      return Media.memory(data, type: mimeType);
    }

    final selectedUri =
        quality?.url ??
        qualities.firstWhereOrNull((item) => item.url != null)?.url ??
        uri;

    return Media(
      selectedUri,
      httpHeaders: headers,
      extras: <String, Object?>{
        ...extras,
        if (title != null) 'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (poster != null) 'poster': poster,
        if (drm != null) 'drm': drm!.scheme.name,
      },
      start: start,
      end: end,
    );
  }
}

PrysmVideoSourceType _inferNetworkType(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('.m3u8')) return PrysmVideoSourceType.hls;
  if (lower.contains('.mpd')) return PrysmVideoSourceType.dash;
  return PrysmVideoSourceType.network;
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}

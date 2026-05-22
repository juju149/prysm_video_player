import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data_source/prysm_video_source.dart';
import 'prysm_cache_config.dart';
import 'prysm_video_cache_base.dart';

PrysmVideoCache createPrysmVideoCache() {
  return PrysmFileVideoCache();
}

class PrysmFileVideoCache implements PrysmVideoCache {
  PrysmFileVideoCache({
    http.Client? client,
    this.directory,
    this.namespace = 'prysm_video_cache',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Directory? directory;
  final String namespace;

  @override
  Future<PrysmCacheResolveResult> resolve(
    PrysmVideoSource source,
    PrysmCacheConfig config,
  ) async {
    if (config.policy == PrysmCachePolicy.disabled) {
      return PrysmCacheResolveResult(
        source: source,
        reason: PrysmCacheResolveReason.disabled,
      );
    }

    if (source.isPlaylist) {
      final results = await Future.wait(
        source.items.map((item) => resolve(item, config)),
      );
      return PrysmCacheResolveResult(
        source: PrysmVideoSource.playlist(
          results.map((result) => result.source).toList(growable: false),
          title: source.title,
          poster: source.poster,
        ),
        reason: results.any((result) => result.resolvedToCachedFile)
            ? PrysmCacheResolveReason.hit
            : PrysmCacheResolveReason.unsupportedSource,
      );
    }

    if (!_canCacheSource(source)) {
      return PrysmCacheResolveResult(
        source: source,
        reason: PrysmCacheResolveReason.unsupportedSource,
      );
    }

    if (source.protected && !config.cacheProtectedSources) {
      return PrysmCacheResolveResult(
        source: source,
        reason: PrysmCacheResolveReason.protectedSource,
      );
    }

    final key = _cacheKey(source);
    final root = await _root();
    await root.create(recursive: true);
    await _evictExpired(root, config);
    final metadataFile = File('${root.path}${Platform.pathSeparator}$key.json');
    final mediaFile = File('${root.path}${Platform.pathSeparator}$key.media');

    if (config.policy == PrysmCachePolicy.metadataOnly) {
      await _writeMetadata(metadataFile, source, key, bytes: null);
      return PrysmCacheResolveResult(
        source: source,
        reason: PrysmCacheResolveReason.metadataStored,
        cacheKey: key,
      );
    }

    if (config.policy == PrysmCachePolicy.firstSeconds) {
      final bytes = await _downloadRange(source, mediaFile, config);
      await _writeMetadata(metadataFile, source, key, bytes: bytes);
      return PrysmCacheResolveResult(
        source: source,
        reason: PrysmCacheResolveReason.partialStored,
        cacheKey: key,
        path: mediaFile.path,
        bytes: bytes,
      );
    }

    if (await mediaFile.exists() && await _isFresh(metadataFile, config)) {
      final bytes = await mediaFile.length();
      return PrysmCacheResolveResult(
        source: source.asCachedFile(mediaFile.path),
        reason: PrysmCacheResolveReason.hit,
        cacheKey: key,
        path: mediaFile.path,
        bytes: bytes,
      );
    }

    final bytes = await _downloadFull(source, mediaFile);
    await _writeMetadata(metadataFile, source, key, bytes: bytes);
    await _enforceMaxBytes(root, config.maxBytes);
    return PrysmCacheResolveResult(
      source: source.asCachedFile(mediaFile.path),
      reason: PrysmCacheResolveReason.miss,
      cacheKey: key,
      path: mediaFile.path,
      bytes: bytes,
    );
  }

  @override
  Future<void> evict(String cacheKey) async {
    final root = await _root();
    final mediaFile = File(
      '${root.path}${Platform.pathSeparator}$cacheKey.media',
    );
    final metadataFile = File(
      '${root.path}${Platform.pathSeparator}$cacheKey.json',
    );
    if (await mediaFile.exists()) await mediaFile.delete();
    if (await metadataFile.exists()) await metadataFile.delete();
  }

  @override
  Future<void> clear() async {
    final root = await _root();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  Future<Directory> _root() async {
    if (directory != null) return directory!;
    final cacheRoot = await getApplicationCacheDirectory();
    return Directory('${cacheRoot.path}${Platform.pathSeparator}$namespace');
  }

  bool _canCacheSource(PrysmVideoSource source) {
    return !source.isLive &&
        !source.isAdaptiveStream &&
        (source.type == PrysmVideoSourceType.network ||
            source.type == PrysmVideoSourceType.blob);
  }

  String _cacheKey(PrysmVideoSource source) {
    final payload = jsonEncode(<String, Object?>{
      'uri': source.uri,
      'headers': source.headers,
      'start': source.start?.inMilliseconds,
      'end': source.end?.inMilliseconds,
    });
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Future<int> _downloadFull(PrysmVideoSource source, File mediaFile) async {
    final uri = Uri.parse(source.uri);
    final request = http.Request('GET', uri)..headers.addAll(source.headers);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Video cache download failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }

    final temp = File('${mediaFile.path}.tmp');
    if (await temp.exists()) await temp.delete();
    final sink = temp.openWrite();
    var bytes = 0;
    await for (final chunk in response.stream) {
      bytes += chunk.length;
      sink.add(chunk);
    }
    await sink.close();
    if (await mediaFile.exists()) await mediaFile.delete();
    await temp.rename(mediaFile.path);
    return bytes;
  }

  Future<int> _downloadRange(
    PrysmVideoSource source,
    File mediaFile,
    PrysmCacheConfig config,
  ) async {
    final request = http.Request('GET', Uri.parse(source.uri))
      ..headers.addAll(source.headers)
      ..headers['Range'] = 'bytes=0-${config.firstChunkBytes - 1}';
    final response = await _client.send(request);
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException(
        'Video cache range download failed with HTTP ${response.statusCode}.',
        uri: Uri.parse(source.uri),
      );
    }

    final sink = mediaFile.openWrite();
    var bytes = 0;
    await for (final chunk in response.stream) {
      bytes += chunk.length;
      sink.add(chunk);
      if (bytes >= config.firstChunkBytes) break;
    }
    await sink.close();
    return bytes;
  }

  Future<void> _writeMetadata(
    File metadataFile,
    PrysmVideoSource source,
    String key, {
    required int? bytes,
  }) async {
    final payload = <String, Object?>{
      'key': key,
      'uri': source.uri,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'bytes': bytes,
      'title': source.title,
      'poster': source.poster,
      'protected': source.protected,
    };
    await metadataFile.writeAsString(jsonEncode(payload));
  }

  Future<bool> _isFresh(File metadataFile, PrysmCacheConfig config) async {
    if (!await metadataFile.exists()) return false;
    final raw = await metadataFile.readAsString();
    final json = jsonDecode(raw);
    if (json is! Map<String, Object?>) return false;
    final cachedAtRaw = json['cachedAt'];
    if (cachedAtRaw is! String) return false;
    final cachedAt = DateTime.tryParse(cachedAtRaw);
    if (cachedAt == null) return false;
    return DateTime.now().toUtc().difference(cachedAt.toUtc()) <= config.maxAge;
  }

  Future<void> _evictExpired(Directory root, PrysmCacheConfig config) async {
    if (!await root.exists()) return;
    await for (final entity in root.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      if (await _isFresh(entity, config)) continue;
      final key = entity.uri.pathSegments.last.replaceAll('.json', '');
      await evict(key);
    }
  }

  Future<void> _enforceMaxBytes(Directory root, int maxBytes) async {
    if (maxBytes <= 0 || !await root.exists()) return;
    final files = <File>[];
    await for (final entity in root.list()) {
      if (entity is File && entity.path.endsWith('.media')) {
        files.add(entity);
      }
    }
    files.sort((a, b) {
      return a.statSync().modified.compareTo(b.statSync().modified);
    });

    var total = 0;
    for (final file in files) {
      total += await file.length();
    }
    for (final file in files) {
      if (total <= maxBytes) return;
      final bytes = await file.length();
      final key = file.uri.pathSegments.last.replaceAll('.media', '');
      await evict(key);
      total -= bytes;
    }
  }
}

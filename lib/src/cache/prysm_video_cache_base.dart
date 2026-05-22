import '../data_source/prysm_video_source.dart';
import 'prysm_cache_config.dart';

enum PrysmCacheResolveReason {
  disabled,
  unsupportedPlatform,
  unsupportedSource,
  protectedSource,
  metadataStored,
  partialStored,
  hit,
  miss,
}

class PrysmCacheResolveResult {
  const PrysmCacheResolveResult({
    required this.source,
    required this.reason,
    this.cacheKey,
    this.path,
    this.bytes,
  });

  final PrysmVideoSource source;
  final PrysmCacheResolveReason reason;
  final String? cacheKey;
  final String? path;
  final int? bytes;

  bool get resolvedToCachedFile =>
      reason == PrysmCacheResolveReason.hit ||
      reason == PrysmCacheResolveReason.miss;
}

abstract interface class PrysmVideoCache {
  Future<PrysmCacheResolveResult> resolve(
    PrysmVideoSource source,
    PrysmCacheConfig config,
  );

  Future<void> evict(String cacheKey);

  Future<void> clear();
}

class PrysmNoopVideoCache implements PrysmVideoCache {
  const PrysmNoopVideoCache({
    this.reason = PrysmCacheResolveReason.unsupportedPlatform,
  });

  final PrysmCacheResolveReason reason;

  @override
  Future<PrysmCacheResolveResult> resolve(
    PrysmVideoSource source,
    PrysmCacheConfig config,
  ) async {
    return PrysmCacheResolveResult(source: source, reason: reason);
  }

  @override
  Future<void> clear() async {}

  @override
  Future<void> evict(String cacheKey) async {}
}

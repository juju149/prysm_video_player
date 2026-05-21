enum PrysmCachePolicy { disabled, metadataOnly, firstSeconds, fullFile }

class PrysmCacheConfig {
  const PrysmCacheConfig({
    required this.policy,
    this.maxBytes = 512 * 1024 * 1024,
    this.maxAge = const Duration(days: 7),
    this.preloadDuration = const Duration(seconds: 15),
    this.cacheProtectedSources = false,
    this.cacheThumbnails = true,
  });

  const PrysmCacheConfig.disabled()
    : policy = PrysmCachePolicy.disabled,
      maxBytes = 0,
      maxAge = Duration.zero,
      preloadDuration = Duration.zero,
      cacheProtectedSources = false,
      cacheThumbnails = false;

  final PrysmCachePolicy policy;
  final int maxBytes;
  final Duration maxAge;
  final Duration preloadDuration;
  final bool cacheProtectedSources;
  final bool cacheThumbnails;
}

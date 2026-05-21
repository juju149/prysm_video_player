class PrysmWebPolicy {
  const PrysmWebPolicy({
    this.autoplayRequiresMuted = true,
    this.requiresCorsForNetworkSources = true,
    this.customHeadersMayRequireNativeBackend = true,
  });

  final bool autoplayRequiresMuted;
  final bool requiresCorsForNetworkSources;
  final bool customHeadersMayRequireNativeBackend;
}

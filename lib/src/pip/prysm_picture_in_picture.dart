enum PrysmPictureInPictureSupport {
  unsupported,
  backendManaged,
  platformCustom,
}

class PrysmPictureInPictureState {
  const PrysmPictureInPictureState({
    this.support = PrysmPictureInPictureSupport.unsupported,
    this.enabled = false,
  });

  final PrysmPictureInPictureSupport support;
  final bool enabled;
}

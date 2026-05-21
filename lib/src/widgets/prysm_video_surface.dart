import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../controller/prysm_video_controller.dart';

class PrysmVideoSurface extends StatelessWidget {
  const PrysmVideoSurface({
    required this.controller,
    super.key,
    this.fit = BoxFit.contain,
    this.aspectRatio,
    this.pauseWhenBackgrounded = true,
    this.resumeWhenForegrounded = false,
  });

  final PrysmVideoController controller;
  final BoxFit fit;
  final double? aspectRatio;
  final bool pauseWhenBackgrounded;
  final bool resumeWhenForegrounded;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Video(
        controller: controller.videoController,
        fit: fit,
        aspectRatio: aspectRatio,
        controls: null,
        pauseUponEnteringBackgroundMode: pauseWhenBackgrounded,
        resumeUponEnteringForegroundMode: resumeWhenForegrounded,
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

class PrysmGestureConfig {
  const PrysmGestureConfig({
    this.doubleTapSeek = const Duration(seconds: 10),
    this.horizontalSeekSensitivity = 450,
    this.verticalVolumeSensitivity = 260,
    this.enableHaptics = true,
    this.enablePinchZoom = false,
  });

  final Duration doubleTapSeek;
  final double horizontalSeekSensitivity;
  final double verticalVolumeSensitivity;
  final bool enableHaptics;
  final bool enablePinchZoom;
}

class PrysmSeekPreview {
  const PrysmSeekPreview({required this.position, required this.localPosition});

  final Duration position;
  final Offset localPosition;
}

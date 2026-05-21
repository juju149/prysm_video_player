import 'package:flutter/material.dart';

import '../core/prysm_video_labels.dart';
import '../subtitles/prysm_subtitles.dart';

enum PrysmControlsDensity { compact, comfortable, tv }

class PrysmVideoTheme {
  const PrysmVideoTheme({
    this.backgroundColor = Colors.black,
    this.scrimColor = const Color(0x99000000),
    this.primaryColor = Colors.white,
    this.secondaryColor = const Color(0xB3FFFFFF),
    this.trackColor = const Color(0x40FFFFFF),
    this.bufferColor = const Color(0x66FFFFFF),
    this.accentColor = const Color(0xFFFFFFFF),
    this.errorColor = const Color(0xFFFF5A5F),
    this.warningColor = const Color(0xFFFFC857),
    this.controlRadius = 8,
    this.compactBreakpoint = 560,
    this.density = PrysmControlsDensity.comfortable,
    this.labels = const PrysmVideoLabels(),
    this.subtitleStyle = const PrysmSubtitleStyle(),
  });

  const PrysmVideoTheme.dark() : this();

  const PrysmVideoTheme.tv()
    : this(
        controlRadius: 8,
        compactBreakpoint: 720,
        density: PrysmControlsDensity.tv,
      );

  final Color backgroundColor;
  final Color scrimColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;
  final Color bufferColor;
  final Color accentColor;
  final Color errorColor;
  final Color warningColor;
  final double controlRadius;
  final double compactBreakpoint;
  final PrysmControlsDensity density;
  final PrysmVideoLabels labels;
  final PrysmSubtitleStyle subtitleStyle;
}

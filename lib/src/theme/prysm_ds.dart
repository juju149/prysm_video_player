import 'package:flutter/material.dart';

/// Design-system tokens for PrysmVideoPlayer.
/// All UI constants live here — nothing is hardcoded in widgets.
abstract final class PrysmDS {
  // ── Durations ─────────────────────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 350);

  // ── Curves ────────────────────────────────────────────────────────────────
  static const Curve curveOut = Curves.easeOutCubic;
  static const Curve curveIn = Curves.easeInCubic;
  static const Curve curveInOut = Curves.easeInOutCubic;

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double sp4 = 4;
  static const double sp6 = 6;
  static const double sp8 = 8;
  static const double sp12 = 12;
  static const double sp14 = 14;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp48 = 48;

  // ── Border radius ─────────────────────────────────────────────────────────
  static const double r4 = 4;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r24 = 24;
  static const double rFull = 999;

  // ── Platform breakpoints ──────────────────────────────────────────────────
  /// Below this width the mobile layout is used.
  static const double bpMobile = 600;
  /// Above this width + TV density the TV layout is used.
  static const double bpTv = 1100;

  // ── Button touch-target sizes ─────────────────────────────────────────────
  static const double btnSm = 36; // compact secondary (mute, pip, fullscreen)
  static const double btnMd = 44; // default icon button
  static const double btnLg = 54; // seek ±10 mobile
  static const double btnXl = 72; // center play/pause mobile
  static const double btnTvSm = 56;
  static const double btnTvPlay = 88;

  // ── Icon sizes ────────────────────────────────────────────────────────────
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double iconXl = 38;
  static const double iconTv = 48;

  // ── Progress bar ──────────────────────────────────────────────────────────
  static const double trackIdle = 3.0;
  static const double trackActive = 5.0;
  static const double thumbRadius = 7.0;

  // ── Typography ────────────────────────────────────────────────────────────
  static const double textXs = 10;
  static const double textSm = 12;
  static const double textMd = 14;
  static const double textLg = 16;
  static const double textXl = 20;

  // ── Opacities ─────────────────────────────────────────────────────────────
  static const double opButtonBg = 0.10;
  static const double opButtonHover = 0.16;
  static const double opButtonPress = 0.24;

  // ── Scrim gradient (top-transparent-transparent-bottom) ───────────────────
  static const List<Color> scrimColors = <Color>[
    Color(0xD0000000),
    Color(0x50000000),
    Color(0x00000000),
    Color(0x00000000),
    Color(0x55000000),
    Color(0xE5000000),
  ];
  static const List<double> scrimStops = <double>[
    0.0,
    0.18,
    0.36,
    0.64,
    0.82,
    1.0,
  ];
}

/// Which layout the controls should render for.
enum PrysmPlayerPlatform { mobile, desktop, tv }

extension PrysmPlayerPlatformX on BuildContext {
  /// Derives the effective player platform from Flutter's platform + layout width.
  PrysmPlayerPlatform playerPlatform(double width, bool isTvDensity) {
    if (isTvDensity && width >= PrysmDS.bpTv) return PrysmPlayerPlatform.tv;
    final p = Theme.of(this).platform;
    if (p == TargetPlatform.android || p == TargetPlatform.iOS) {
      return PrysmPlayerPlatform.mobile;
    }
    if (width < PrysmDS.bpMobile) return PrysmPlayerPlatform.mobile;
    return PrysmPlayerPlatform.desktop;
  }
}

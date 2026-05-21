import 'package:flutter/material.dart';

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
    this.controlRadius = 18,
    this.compactBreakpoint = 560,
  });

  final Color backgroundColor;
  final Color scrimColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;
  final Color bufferColor;
  final Color accentColor;
  final Color errorColor;
  final double controlRadius;
  final double compactBreakpoint;
}

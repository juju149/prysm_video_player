import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/prysm_video_controller.dart';
import '../core/prysm_video_config.dart';
import '../theme/prysm_video_theme.dart';
import '../widgets/prysm_video_player.dart';

class PrysmFullscreenRoute extends PageRouteBuilder<void> {
  PrysmFullscreenRoute({
    required PrysmVideoController controller,
    required PrysmVideoConfig config,
    required PrysmVideoTheme theme,
  }) : super(
         opaque: true,
         barrierColor: Colors.black,
         pageBuilder: (context, animation, secondaryAnimation) {
           return _FullscreenShell(
             controller: controller,
             config: config,
             theme: theme,
           );
         },
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return FadeTransition(opacity: animation, child: child);
         },
       );
}

class _FullscreenShell extends StatefulWidget {
  const _FullscreenShell({
    required this.controller,
    required this.config,
    required this.theme,
  });

  final PrysmVideoController controller;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;

  @override
  State<_FullscreenShell> createState() => _FullscreenShellState();
}

class _FullscreenShellState extends State<_FullscreenShell> {
  @override
  void initState() {
    super.initState();
    // Defer enterFullscreen so that notifyListeners() is not called during
    // the widget's own mount phase (which would trigger setState-during-build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.enterFullscreen());
    });
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    unawaited(widget.controller.exitFullscreen());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PrysmVideoPlayer(
        controller: widget.controller,
        config: widget.config.copyWith(
          aspectRatio: null,
          enableFullscreen: false,
        ),
        theme: widget.theme,
      ),
    );
  }
}

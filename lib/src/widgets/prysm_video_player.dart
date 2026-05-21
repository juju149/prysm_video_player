import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/prysm_video_controller.dart';
import '../core/prysm_video_config.dart';
import '../core/prysm_video_event.dart';
import '../core/prysm_video_state.dart';
import '../fullscreen/prysm_fullscreen.dart';
import '../theme/prysm_ds.dart';
import '../theme/prysm_video_theme.dart';
import '../tracks/prysm_tracks.dart';
import 'prysm_video_surface.dart';

typedef PrysmVideoControlsBuilder =
    Widget Function(
      BuildContext context,
      PrysmVideoController controller,
      PrysmVideoState state,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

class PrysmVideoPlayer extends StatefulWidget {
  const PrysmVideoPlayer({
    required this.controller,
    super.key,
    this.theme = const PrysmVideoTheme.dark(),
    this.controls,
    this.onEvent,
    this.config,
  });

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;
  final PrysmVideoControlsBuilder? controls;
  final ValueChanged<PrysmVideoEvent>? onEvent;
  final PrysmVideoConfig? config;

  @override
  State<PrysmVideoPlayer> createState() => _PrysmVideoPlayerState();
}

class _PrysmVideoPlayerState extends State<PrysmVideoPlayer> {
  late PrysmVideoConfig _config;
  late StreamSubscription<PrysmVideoEvent> _eventSub;
  final FocusNode _focusNode = FocusNode(debugLabel: 'PrysmVideoPlayer');
  Timer? _hideTimer;
  bool _controlsVisible = true;

  // Seek-feedback notifier — updated on double-tap, read by _SeekFeedback.
  final ValueNotifier<_SeekDir?> _seekDir = ValueNotifier(null);
  Timer? _seekFeedbackTimer;

  PrysmVideoController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? widget.controller.config;
    _eventSub = _ctrl.events.listen((e) => widget.onEvent?.call(e));
    if (_ctrl.source != null &&
        _ctrl.state.status == PrysmPlaybackStatus.idle) {
      unawaited(_ctrl.open(_ctrl.source!));
    }
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant PrysmVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _eventSub.cancel();
      _eventSub = _ctrl.events.listen((e) => widget.onEvent?.call(e));
    }
    _config = widget.config ?? widget.controller.config;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _seekDir.dispose();
    _focusNode.dispose();
    unawaited(_eventSub.cancel());
    super.dispose();
  }

  // ── Controls visibility ───────────────────────────────────────────────────

  void _showControls() {
    if (!_controlsVisible && mounted) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_ctrl.state.controlsLocked) return;
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_config.autoHideControls || !_config.showControls) return;
    _hideTimer = Timer(_config.controlsAutoHideDelay, () {
      if (!mounted) return;
      if (_ctrl.state.playing && !_ctrl.state.controlsLocked) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  // ── Keyboard ──────────────────────────────────────────────────────────────

  KeyEventResult _onKey(KeyEvent event) {
    if (!_config.enableKeyboard || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      unawaited(_ctrl.toggle());
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_ctrl.seekBy(-_config.seekStep));
      _flashSeek(_SeekDir.left);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(_ctrl.seekBy(_config.seekStep));
      _flashSeek(_SeekDir.right);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      unawaited(_ctrl.setVolume(_ctrl.state.volume + 5));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      unawaited(_ctrl.setVolume(_ctrl.state.volume - 5));
    } else if (key == LogicalKeyboardKey.keyM) {
      unawaited(_ctrl.toggleMute());
    } else if (key == LogicalKeyboardKey.keyF && _config.enableFullscreen) {
      unawaited(_enterFullscreen());
    } else if (key == LogicalKeyboardKey.escape && _ctrl.state.fullscreen) {
      Navigator.of(context).maybePop();
    } else if (_isDigitKey(key)) {
      final digit = _digitValue(key);
      if (digit != null && _ctrl.state.duration > Duration.zero) {
        unawaited(_ctrl.seekTo(_ctrl.state.duration * (digit / 10)));
      }
    } else {
      return KeyEventResult.ignored;
    }
    _showControls();
    return KeyEventResult.handled;
  }

  // ── Gestures ──────────────────────────────────────────────────────────────

  Offset? _doubleTapPos;

  void _handleDoubleTapDown(TapDownDetails d) => _doubleTapPos = d.localPosition;

  void _handleDoubleTap(Size size) {
    final dx = _doubleTapPos?.dx ?? size.width / 2;
    if (dx < size.width * 0.35) {
      unawaited(_ctrl.seekBy(-_config.seekStep));
      _flashSeek(_SeekDir.left);
    } else if (dx > size.width * 0.65) {
      unawaited(_ctrl.seekBy(_config.seekStep));
      _flashSeek(_SeekDir.right);
    } else {
      unawaited(_ctrl.toggle());
    }
    HapticFeedback.selectionClick();
    _showControls();
  }

  void _handleVerticalDrag(DragUpdateDetails d, Size size) {
    if (!_config.enableGestures || size.width <= 0) return;
    if (d.localPosition.dx < size.width / 2) return;
    unawaited(_ctrl.setVolume(_ctrl.state.volume + (-d.delta.dy / 2)));
    _showControls();
  }

  void _flashSeek(_SeekDir dir) {
    _seekDir.value = dir;
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      _seekDir.value = null;
    });
  }

  // ── Fullscreen ────────────────────────────────────────────────────────────

  Future<void> _enterFullscreen() async {
    await Navigator.of(context).push(
      PrysmFullscreenRoute(
        controller: _ctrl,
        config: _config,
        theme: widget.theme,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final player = LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onHover: (_) => _showControls(),
          cursor: _controlsVisible || !_ctrl.state.fullscreen
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKey,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _config.enableGestures ? _toggleControls : null,
              onDoubleTapDown:
                  _config.enableGestures ? _handleDoubleTapDown : null,
              onDoubleTap: _config.enableGestures
                  ? () => _handleDoubleTap(size)
                  : null,
              onVerticalDragUpdate: _config.enableGestures
                  ? (d) => _handleVerticalDrag(d, size)
                  : null,
              child: ColoredBox(
                color: widget.theme.backgroundColor,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // ── Video surface (isolated repaint boundary) ──────────
                    PrysmVideoSurface(
                      controller: _ctrl,
                      fit: _config.fit,
                      aspectRatio: _config.aspectRatio,
                      pauseWhenBackgrounded: _config.pauseWhenBackgrounded,
                      resumeWhenForegrounded: _config.resumeWhenForegrounded,
                    ),

                    // ── Always-visible state overlays ──────────────────────
                    if (_config.showControls)
                      _StateOverlay(controller: _ctrl, theme: widget.theme),

                    // ── Interactive controls overlay ───────────────────────
                    if (_config.showControls)
                      RepaintBoundary(
                        child: widget.controls != null
                            ? AnimatedBuilder(
                                animation: _ctrl,
                                builder: (context, _) => widget.controls!(
                                  context,
                                  _ctrl,
                                  _ctrl.state,
                                ),
                              )
                            : _PremiumControls(
                                controller: _ctrl,
                                visible: _controlsVisible,
                                config: _config,
                                theme: widget.theme,
                                seekDir: _seekDir,
                                onInteraction: _showControls,
                                onFullscreen: _config.enableFullscreen
                                    ? _enterFullscreen
                                    : null,
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    final ar = _config.aspectRatio;
    if (ar == null) return player;
    return AspectRatio(aspectRatio: ar, child: player);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// State overlay — buffering spinner + error panel (always visible)
// ─────────────────────────────────────────────────────────────────────────────

class _StateOverlay extends StatelessWidget {
  const _StateOverlay({required this.controller, required this.theme});

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        if (state.error != null) {
          return Center(
            child: _ErrorOverlay(
              controller: controller,
              state: state,
              theme: theme,
            ),
          );
        }
        if (state.buffering || state.status == PrysmPlaybackStatus.opening) {
          return const Center(child: _LoadingSpinner());
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium controls — platform-adaptive dispatcher
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumControls extends StatelessWidget {
  const _PremiumControls({
    required this.controller,
    required this.visible,
    required this.config,
    required this.theme,
    required this.seekDir,
    required this.onInteraction,
    required this.onFullscreen,
  });

  final PrysmVideoController controller;
  final bool visible;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final ValueNotifier<_SeekDir?> seekDir;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isTv = theme.density == PrysmControlsDensity.tv;
        final platform = context.playerPlatform(width, isTv);

        final controls = switch (platform) {
          PrysmPlayerPlatform.tv => _TvControls(
              controller: controller,
              visible: visible,
              config: config,
              theme: theme,
              seekDir: seekDir,
              onInteraction: onInteraction,
              onFullscreen: onFullscreen,
            ),
          PrysmPlayerPlatform.mobile => _MobileControls(
              controller: controller,
              visible: visible,
              config: config,
              theme: theme,
              seekDir: seekDir,
              onInteraction: onInteraction,
              onFullscreen: onFullscreen,
            ),
          PrysmPlayerPlatform.desktop => _DesktopControls(
              controller: controller,
              visible: visible,
              config: config,
              theme: theme,
              seekDir: seekDir,
              onInteraction: onInteraction,
              onFullscreen: onFullscreen,
            ),
        };

        return controls;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared controls props mixin (passed to all three layouts)
// ─────────────────────────────────────────────────────────────────────────────

abstract class _ControlsLayout extends StatelessWidget {
  const _ControlsLayout({
    required this.controller,
    required this.visible,
    required this.config,
    required this.theme,
    required this.seekDir,
    required this.onInteraction,
    required this.onFullscreen,
  });

  final PrysmVideoController controller;
  final bool visible;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final ValueNotifier<_SeekDir?> seekDir;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;

  Widget buildScrim() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: PrysmDS.scrimColors,
            stops: PrysmDS.scrimStops,
          ),
        ),
        child: const SizedBox.expand(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile controls layout
// ─────────────────────────────────────────────────────────────────────────────

class _MobileControls extends _ControlsLayout {
  const _MobileControls({
    required super.controller,
    required super.visible,
    required super.config,
    required super.theme,
    required super.seekDir,
    required super.onInteraction,
    required super.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: visible ? PrysmDS.standard : PrysmDS.fast,
        curve: PrysmDS.curveOut,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            buildScrim(),
            // Seek feedback
            _SeekFeedback(
              notifier: seekDir,
              seconds: config.seekStep.inSeconds,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PrysmDS.sp16,
                  vertical: PrysmDS.sp12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Top bar
                    _TopBar(
                      controller: controller,
                      theme: theme,
                      onInteraction: onInteraction,
                    ),
                    const Spacer(),
                    // Center: seek + play/pause
                    Center(
                      child: _CenterRow(
                        controller: controller,
                        config: config,
                        theme: theme,
                        playSize: PrysmDS.btnXl,
                        playIconSize: PrysmDS.iconXl,
                        seekSize: PrysmDS.btnLg,
                        seekIconSize: PrysmDS.iconLg,
                        gap: PrysmDS.sp32,
                        onInteraction: onInteraction,
                      ),
                    ),
                    const Spacer(),
                    // Bottom bar
                    _BottomBar(
                      controller: controller,
                      config: config,
                      theme: theme,
                      onInteraction: onInteraction,
                      onFullscreen: onFullscreen,
                      timeStyle: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: PrysmDS.textSm,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop controls layout
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopControls extends _ControlsLayout {
  const _DesktopControls({
    required super.controller,
    required super.visible,
    required super.config,
    required super.theme,
    required super.seekDir,
    required super.onInteraction,
    required super.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: visible ? PrysmDS.standard : PrysmDS.fast,
        curve: PrysmDS.curveOut,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            buildScrim(),
            _SeekFeedback(
              notifier: seekDir,
              seconds: config.seekStep.inSeconds,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(PrysmDS.sp20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _TopBar(
                      controller: controller,
                      theme: theme,
                      onInteraction: onInteraction,
                    ),
                    const Spacer(),
                    Center(
                      child: _CenterRow(
                        controller: controller,
                        config: config,
                        theme: theme,
                        playSize: 78,
                        playIconSize: PrysmDS.iconXl,
                        seekSize: PrysmDS.btnMd + 10,
                        seekIconSize: PrysmDS.iconLg,
                        gap: PrysmDS.sp24,
                        onInteraction: onInteraction,
                      ),
                    ),
                    const Spacer(),
                    _BottomBar(
                      controller: controller,
                      config: config,
                      theme: theme,
                      onInteraction: onInteraction,
                      onFullscreen: onFullscreen,
                      timeStyle: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: PrysmDS.textMd,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV controls layout
// ─────────────────────────────────────────────────────────────────────────────

class _TvControls extends _ControlsLayout {
  const _TvControls({
    required super.controller,
    required super.visible,
    required super.config,
    required super.theme,
    required super.seekDir,
    required super.onInteraction,
    required super.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: visible ? PrysmDS.standard : PrysmDS.fast,
        curve: PrysmDS.curveOut,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            buildScrim(),
            _SeekFeedback(
              notifier: seekDir,
              seconds: config.seekStep.inSeconds,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PrysmDS.sp48,
                  vertical: PrysmDS.sp32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _TopBar(
                      controller: controller,
                      theme: theme,
                      onInteraction: onInteraction,
                      titleFontSize: PrysmDS.textXl,
                    ),
                    const Spacer(),
                    // TV: progress bar full width at bottom
                    _ProgressBar(
                      controller: controller,
                      theme: theme,
                      onInteraction: onInteraction,
                    ),
                    const SizedBox(height: PrysmDS.sp16),
                    Row(
                      children: <Widget>[
                        _TimeDisplay(controller: controller, theme: theme),
                        const Spacer(),
                        // TV action row — large buttons, focused navigation
                        _TvActionRow(
                          controller: controller,
                          config: config,
                          theme: theme,
                          onInteraction: onInteraction,
                          onFullscreen: onFullscreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

// Top bar — close + title + live badge
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.theme,
    required this.onInteraction,
    this.titleFontSize = PrysmDS.textLg,
  });

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final source = controller.state.source;
        final isLive = controller.state.live;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (Navigator.of(context).canPop()) ...<Widget>[
              _PlayerButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: theme.labels.exitFullscreen,
                theme: theme,
                size: PrysmDS.btnSm,
                iconSize: PrysmDS.iconMd,
                onTap: () {
                  onInteraction();
                  Navigator.of(context).maybePop();
                },
              ),
              const SizedBox(width: PrysmDS.sp12),
            ],
            if (source?.title != null || source?.subtitle != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (source?.title != null)
                      Text(
                        source!.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    if (source?.subtitle != null)
                      Text(
                        source!.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.secondaryColor,
                          fontSize: PrysmDS.textSm,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            if (isLive) ...<Widget>[
              const SizedBox(width: PrysmDS.sp12),
              _LiveBadge(label: theme.labels.live),
            ],
          ],
        );
      },
    );
  }
}

// Center: seek-back, play/pause, seek-forward
class _CenterRow extends StatelessWidget {
  const _CenterRow({
    required this.controller,
    required this.config,
    required this.theme,
    required this.playSize,
    required this.playIconSize,
    required this.seekSize,
    required this.seekIconSize,
    required this.gap,
    required this.onInteraction,
  });

  final PrysmVideoController controller;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final double playSize;
  final double playIconSize;
  final double seekSize;
  final double seekIconSize;
  final double gap;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final playing = controller.state.playing;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _PlayerButton(
              icon: Icons.replay_10_rounded,
              tooltip:
                  '${theme.labels.seekBackward} ${config.seekStep.inSeconds}s',
              theme: theme,
              size: seekSize,
              iconSize: seekIconSize,
              onTap: () {
                onInteraction();
                unawaited(controller.seekBy(-config.seekStep));
              },
            ),
            SizedBox(width: gap),
            _PlayPauseButton(
              playing: playing,
              theme: theme,
              size: playSize,
              iconSize: playIconSize,
              onTap: () {
                onInteraction();
                unawaited(controller.toggle());
              },
            ),
            SizedBox(width: gap),
            _PlayerButton(
              icon: Icons.forward_10_rounded,
              tooltip:
                  '${theme.labels.seekForward} ${config.seekStep.inSeconds}s',
              theme: theme,
              size: seekSize,
              iconSize: seekIconSize,
              onTap: () {
                onInteraction();
                unawaited(controller.seekBy(config.seekStep));
              },
            ),
          ],
        );
      },
    );
  }
}

// Bottom bar — progress, time, action buttons
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.controller,
    required this.config,
    required this.theme,
    required this.onInteraction,
    required this.onFullscreen,
    required this.timeStyle,
  });

  final PrysmVideoController controller;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;
  final TextStyle timeStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ProgressBar(
          controller: controller,
          theme: theme,
          onInteraction: onInteraction,
        ),
        const SizedBox(height: PrysmDS.sp4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _TimeDisplay(
              controller: controller,
              theme: theme,
              style: timeStyle,
            ),
            const Spacer(),
            _SettingsButton(
              controller: controller,
              theme: theme,
              onInteraction: onInteraction,
            ),
            const SizedBox(width: PrysmDS.sp4),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => _PlayerButton(
                icon: controller.state.muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                tooltip: controller.state.muted
                    ? theme.labels.unmute
                    : theme.labels.mute,
                theme: theme,
                size: PrysmDS.btnSm,
                iconSize: PrysmDS.iconMd,
                onTap: () {
                  onInteraction();
                  unawaited(controller.toggleMute());
                },
              ),
            ),
            if (config.enablePictureInPicture) ...<Widget>[
              const SizedBox(width: PrysmDS.sp4),
              _PlayerButton(
                icon: Icons.picture_in_picture_alt_rounded,
                tooltip: theme.labels.pictureInPicture,
                theme: theme,
                size: PrysmDS.btnSm,
                iconSize: PrysmDS.iconMd,
                onTap: () {
                  onInteraction();
                  unawaited(controller.enablePictureInPicture());
                },
              ),
            ],
            if (onFullscreen != null) ...<Widget>[
              const SizedBox(width: PrysmDS.sp4),
              _PlayerButton(
                icon: Icons.fullscreen_rounded,
                tooltip: theme.labels.fullscreen,
                theme: theme,
                size: PrysmDS.btnSm,
                iconSize: PrysmDS.iconMd,
                onTap: () {
                  onInteraction();
                  unawaited(onFullscreen!());
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// TV action row — large buttons
class _TvActionRow extends StatelessWidget {
  const _TvActionRow({
    required this.controller,
    required this.config,
    required this.theme,
    required this.onInteraction,
    required this.onFullscreen,
  });

  final PrysmVideoController controller;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _PlayerButton(
              icon: Icons.replay_10_rounded,
              tooltip:
                  '${theme.labels.seekBackward} ${config.seekStep.inSeconds}s',
              theme: theme,
              size: PrysmDS.btnTvSm,
              iconSize: PrysmDS.iconLg,
              onTap: () {
                onInteraction();
                unawaited(controller.seekBy(-config.seekStep));
              },
            ),
            const SizedBox(width: PrysmDS.sp12),
            _PlayPauseButton(
              playing: state.playing,
              theme: theme,
              size: PrysmDS.btnTvPlay,
              iconSize: PrysmDS.iconTv,
              onTap: () {
                onInteraction();
                unawaited(controller.toggle());
              },
            ),
            const SizedBox(width: PrysmDS.sp12),
            _PlayerButton(
              icon: Icons.forward_10_rounded,
              tooltip:
                  '${theme.labels.seekForward} ${config.seekStep.inSeconds}s',
              theme: theme,
              size: PrysmDS.btnTvSm,
              iconSize: PrysmDS.iconLg,
              onTap: () {
                onInteraction();
                unawaited(controller.seekBy(config.seekStep));
              },
            ),
            const SizedBox(width: PrysmDS.sp16),
            _PlayerButton(
              icon: state.muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              tooltip: state.muted ? theme.labels.unmute : theme.labels.mute,
              theme: theme,
              size: PrysmDS.btnTvSm,
              iconSize: PrysmDS.iconLg,
              onTap: () {
                onInteraction();
                unawaited(controller.toggleMute());
              },
            ),
            if (onFullscreen != null) ...<Widget>[
              const SizedBox(width: PrysmDS.sp8),
              _PlayerButton(
                icon: Icons.fullscreen_rounded,
                tooltip: theme.labels.fullscreen,
                theme: theme,
                size: PrysmDS.btnTvSm,
                iconSize: PrysmDS.iconLg,
                onTap: () {
                  onInteraction();
                  unawaited(onFullscreen!());
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Primitive widgets
// ─────────────────────────────────────────────────────────────────────────────

// Premium icon button with hover + press animations
class _PlayerButton extends StatefulWidget {
  const _PlayerButton({
    required this.icon,
    required this.onTap,
    required this.theme,
    this.tooltip,
    this.size = PrysmDS.btnMd,
    this.iconSize = PrysmDS.iconMd,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final PrysmVideoTheme theme;
  final double size;
  final double iconSize;

  @override
  State<_PlayerButton> createState() => _PlayerButtonState();
}

class _PlayerButtonState extends State<_PlayerButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget btn = AnimatedScale(
      scale: _pressed ? 0.88 : (_hovered ? 1.07 : 1.0),
      duration: PrysmDS.fast,
      curve: PrysmDS.curveOut,
      child: AnimatedContainer(
        duration: PrysmDS.fast,
        curve: PrysmDS.curveOut,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withAlpha(61)   // ~0.24
              : _hovered
                  ? Colors.white.withAlpha(41) // ~0.16
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.size / 2),
        ),
        child: Center(
          child: Icon(
            widget.icon,
            color: widget.theme.primaryColor,
            size: widget.iconSize,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Semantics(
          button: true,
          label: widget.tooltip,
          child: btn,
        ),
      ),
    );
  }
}

// Animated play/pause button with icon morphing
class _PlayPauseButton extends StatefulWidget {
  const _PlayPauseButton({
    required this.playing,
    required this.onTap,
    required this.theme,
    required this.size,
    required this.iconSize,
  });

  final bool playing;
  final VoidCallback onTap;
  final PrysmVideoTheme theme;
  final double size;
  final double iconSize;

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Semantics(
          button: true,
          label: widget.playing ? 'Pause' : 'Play',
          child: AnimatedScale(
            scale: _pressed ? 0.90 : (_hovered ? 1.06 : 1.0),
            duration: PrysmDS.fast,
            curve: PrysmDS.curveOut,
            child: AnimatedContainer(
              duration: PrysmDS.fast,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _pressed
                    ? Colors.white.withAlpha(66)
                    : _hovered
                        ? Colors.white.withAlpha(46)
                        : Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(widget.size / 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: PrysmDS.standard,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: anim,
                      curve: PrysmDS.curveOut,
                    ),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    widget.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey<bool>(widget.playing),
                    color: widget.theme.primaryColor,
                    size: widget.iconSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Premium custom progress bar
class _ProgressBar extends StatefulWidget {
  const _ProgressBar({
    required this.controller,
    required this.theme,
    required this.onInteraction,
  });

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _dragging = false;
  double? _dragProgress;
  late AnimationController _hoverCtrl;
  late Animation<double> _trackH;
  late Animation<double> _thumbOp;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(vsync: this, duration: PrysmDS.fast);
    _trackH = Tween<double>(
      begin: PrysmDS.trackIdle,
      end: PrysmDS.trackActive,
    ).animate(CurvedAnimation(parent: _hoverCtrl, curve: PrysmDS.curveOut));
    _thumbOp = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _hoverCtrl, curve: PrysmDS.curveOut),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  void _activate() => _hoverCtrl.forward();

  void _deactivate() {
    if (!_hovering && !_dragging) _hoverCtrl.reverse();
  }

  void _commitSeek(double progress) {
    final dur = widget.controller.state.duration;
    if (dur > Duration.zero) {
      unawaited(widget.controller.seekTo(dur * progress));
    }
    widget.onInteraction();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovering = true);
        _activate();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _deactivate();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) =>
                _commitSeek((d.localPosition.dx / width).clamp(0.0, 1.0)),
            onHorizontalDragStart: (d) {
              setState(() {
                _dragging = true;
                _dragProgress =
                    (d.localPosition.dx / width).clamp(0.0, 1.0);
              });
              _activate();
              widget.onInteraction();
            },
            onHorizontalDragUpdate: (d) {
              setState(() {
                _dragProgress =
                    (d.localPosition.dx / width).clamp(0.0, 1.0);
              });
            },
            onHorizontalDragEnd: (_) {
              if (_dragProgress != null) _commitSeek(_dragProgress!);
              setState(() {
                _dragging = false;
                _dragProgress = null;
              });
              _deactivate();
            },
            child: SizedBox(
              height: 28,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: Listenable.merge(
                  <Listenable>[widget.controller, _hoverCtrl],
                ),
                builder: (context, _) {
                  final state = widget.controller.state;
                  final progress = _dragging
                      ? (_dragProgress ?? state.progress)
                      : state.progress;
                  return CustomPaint(
                    size: Size(width, 28),
                    painter: _ProgressPainter(
                      progress: progress,
                      buffer: state.bufferProgress,
                      trackH: _trackH.value,
                      thumbOp: _thumbOp.value,
                      accentColor: widget.theme.accentColor,
                      bufferColor: widget.theme.bufferColor,
                      trackColor: widget.theme.trackColor,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.progress,
    required this.buffer,
    required this.trackH,
    required this.thumbOp,
    required this.accentColor,
    required this.bufferColor,
    required this.trackColor,
  });

  final double progress;
  final double buffer;
  final double trackH;
  final double thumbOp;
  final Color accentColor;
  final Color bufferColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final half = trackH / 2;
    final r = Radius.circular(trackH);
    final fullWidth = size.width;

    // Background track
    canvas.drawRRect(
      RRect.fromLTRBR(0, cy - half, fullWidth, cy + half, r),
      Paint()..color = trackColor,
    );

    // Buffer
    if (buffer > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          0,
          cy - half,
          (fullWidth * buffer).clamp(0.0, fullWidth),
          cy + half,
          r,
        ),
        Paint()..color = bufferColor,
      );
    }

    // Played
    if (progress > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          0,
          cy - half,
          (fullWidth * progress).clamp(0.0, fullWidth),
          cy + half,
          r,
        ),
        Paint()..color = accentColor,
      );
    }

    // Thumb
    if (thumbOp > 0) {
      final tx = (fullWidth * progress).clamp(0.0, fullWidth);
      canvas.drawCircle(
        Offset(tx, cy),
        PrysmDS.thumbRadius + 2,
        Paint()
          ..color = Colors.black.withAlpha((80 * thumbOp).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(tx, cy),
        PrysmDS.thumbRadius,
        Paint()..color = accentColor.withAlpha((thumbOp * 255).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter o) =>
      o.progress != progress ||
      o.buffer != buffer ||
      o.trackH != trackH ||
      o.thumbOp != thumbOp;
}

// Time display
class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({
    required this.controller,
    required this.theme,
    this.style,
  });

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final text = state.live
            ? theme.labels.live
            : '${_fmt(state.position)} / ${_fmt(state.duration)}';
        return Text(
          text,
          style: style ??
              TextStyle(
                color: theme.secondaryColor,
                fontSize: PrysmDS.textSm,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
        );
      },
    );
  }
}

// Settings button — opens premium bottom sheet
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({
    required this.controller,
    required this.theme,
    required this.onInteraction,
  });

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    return _PlayerButton(
      icon: Icons.tune_rounded,
      tooltip: theme.labels.settings,
      theme: theme,
      size: PrysmDS.btnSm,
      iconSize: PrysmDS.iconMd,
      onTap: () {
        onInteraction();
        _openSettings(context);
      },
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (ctx) => _SettingsSheet(
        controller: controller,
        theme: theme,
      ),
    );
  }
}

// Settings main sheet
class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.controller, required this.theme});

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return _BottomSheet(
          title: theme.labels.settings,
          children: <Widget>[
            _SheetRow(
              label: theme.labels.speed,
              value:
                  '${state.speed.toStringAsFixed(state.speed == 1 ? 0 : 2)}×',
              icon: Icons.speed_rounded,
              onTap: () => _openSpeed(context, state.speed),
            ),
            _SheetRow(
              label: theme.labels.quality,
              value: state.selectedQuality.label,
              icon: Icons.high_quality_rounded,
              onTap: () => _openQuality(context, state),
            ),
            _SheetRow(
              label: theme.labels.subtitles,
              value: state.selectedTracks.subtitle.label,
              icon: Icons.closed_caption_rounded,
              onTap: () => _openSubtitles(context, state),
            ),
            _SheetRow(
              label: theme.labels.audio,
              value: state.selectedTracks.audio.label,
              icon: Icons.headphones_rounded,
              onTap: () => _openAudio(context, state),
            ),
          ],
        );
      },
    );
  }

  void _openSpeed(BuildContext context, double current) {
    const speeds = <double>[0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3];
    Navigator.of(context).pop();
    _showChoiceSheet<double>(
      context,
      title: theme.labels.speed,
      values: speeds,
      label: (v) => v == 1 ? '1× (Normal)' : '$v×',
      selected: current,
      onSelected: controller.setSpeed,
    );
  }

  void _openQuality(BuildContext context, PrysmVideoState state) {
    Navigator.of(context).pop();
    _showChoiceSheet<PrysmVideoQuality>(
      context,
      title: theme.labels.quality,
      values: state.availableQualities,
      label: (v) => v.label,
      selected: state.selectedQuality,
      onSelected: controller.selectVideoQuality,
    );
  }

  void _openSubtitles(BuildContext context, PrysmVideoState state) {
    Navigator.of(context).pop();
    _showChoiceSheet<PrysmSubtitleTrackInfo>(
      context,
      title: theme.labels.subtitles,
      values: state.availableTracks.subtitles,
      label: (v) => v.label,
      selected: state.selectedTracks.subtitle,
      onSelected: (v) => controller.selectSubtitleTrack(v.id),
    );
  }

  void _openAudio(BuildContext context, PrysmVideoState state) {
    Navigator.of(context).pop();
    _showChoiceSheet<PrysmAudioTrack>(
      context,
      title: theme.labels.audio,
      values: state.availableTracks.audio,
      label: (v) => v.label,
      selected: state.selectedTracks.audio,
      onSelected: (v) => controller.selectAudioTrack(v.id),
    );
  }
}

// Premium bottom sheet container
class _BottomSheet extends StatelessWidget {
  const _BottomSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        PrysmDS.sp12,
        0,
        PrysmDS.sp12,
        PrysmDS.sp12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(PrysmDS.r16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: PrysmDS.sp12),
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(PrysmDS.rFull),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PrysmDS.sp20,
              PrysmDS.sp16,
              PrysmDS.sp20,
              PrysmDS.sp8,
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: PrysmDS.textLg,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ...children,
          SizedBox(height: MediaQuery.paddingOf(context).bottom + PrysmDS.sp8),
        ],
      ),
    );
  }
}

// Row inside _BottomSheet
class _SheetRow extends StatefulWidget {
  const _SheetRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_SheetRow> createState() => _SheetRowState();
}

class _SheetRowState extends State<_SheetRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: PrysmDS.fast,
        color: _pressed ? Colors.white.withAlpha(15) : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: PrysmDS.sp20,
          vertical: PrysmDS.sp14,
        ),
        child: Row(
          children: <Widget>[
            Icon(widget.icon, color: Colors.white70, size: PrysmDS.iconMd),
            const SizedBox(width: PrysmDS.sp16),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: PrysmDS.textMd,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              widget.value,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: PrysmDS.textMd,
              ),
            ),
            const SizedBox(width: PrysmDS.sp8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
              size: PrysmDS.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seek feedback overlay
// ─────────────────────────────────────────────────────────────────────────────

enum _SeekDir { left, right }

class _SeekFeedback extends StatefulWidget {
  const _SeekFeedback({
    required this.notifier,
    required this.seconds,
  });

  final ValueNotifier<_SeekDir?> notifier;
  final int seconds;

  @override
  State<_SeekFeedback> createState() => _SeekFeedbackState();
}

class _SeekFeedbackState extends State<_SeekFeedback> {
  _SeekDir? _dir;

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onNotify);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onNotify);
    super.dispose();
  }

  void _onNotify() => setState(() => _dir = widget.notifier.value);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _dir != null ? 1.0 : 0.0,
        duration: _dir != null ? PrysmDS.fast : PrysmDS.standard,
        curve: PrysmDS.curveOut,
        child: Align(
          alignment: _dir == _SeekDir.left
              ? const Alignment(-0.45, 0)
              : const Alignment(0.45, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PrysmDS.sp20,
              vertical: PrysmDS.sp12,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(140),
              borderRadius: BorderRadius.circular(PrysmDS.rFull),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _dir == _SeekDir.left
                  ? <Widget>[
                      const Icon(
                        Icons.replay_rounded,
                        color: Colors.white,
                        size: PrysmDS.iconLg,
                      ),
                      const SizedBox(width: PrysmDS.sp6),
                      Text(
                        '${widget.seconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: PrysmDS.textMd,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]
                  : <Widget>[
                      Text(
                        '${widget.seconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: PrysmDS.textMd,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: PrysmDS.sp6),
                      const Icon(
                        Icons.forward_rounded,
                        color: Colors.white,
                        size: PrysmDS.iconLg,
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live badge
// ─────────────────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrysmDS.sp8,
        vertical: PrysmDS.sp4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE50914),
        borderRadius: BorderRadius.circular(PrysmDS.r4),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: PrysmDS.textXs,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading spinner
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingSpinner extends StatelessWidget {
  const _LoadingSpinner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox.square(
        dimension: 40,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white.withAlpha(220),
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error overlay
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.controller,
    required this.state,
    required this.theme,
  });

  final PrysmVideoController controller;
  final PrysmVideoState state;
  final PrysmVideoTheme theme;

  @override
  Widget build(BuildContext context) {
    final error = state.error;
    return Container(
      padding: const EdgeInsets.all(PrysmDS.sp24),
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0A0A),
        borderRadius: BorderRadius.circular(PrysmDS.r16),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            color: theme.errorColor,
            size: PrysmDS.iconXl,
          ),
          const SizedBox(height: PrysmDS.sp12),
          Text(
            error?.userMessage ?? 'The video could not be played.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: PrysmDS.textMd,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (error?.retryable != false) ...<Widget>[
            const SizedBox(height: PrysmDS.sp20),
            _RetryButton(
              label: theme.labels.retry,
              onTap: state.source == null
                  ? null
                  : () => unawaited(controller.open(state.source!)),
            ),
          ],
        ],
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: PrysmDS.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: PrysmDS.sp24,
            vertical: PrysmDS.sp12,
          ),
          decoration: BoxDecoration(
            color: _pressed
                ? Colors.white.withAlpha(230)
                : _hovered
                    ? Colors.white.withAlpha(245)
                    : Colors.white,
            borderRadius: BorderRadius.circular(PrysmDS.rFull),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: PrysmDS.textMd,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice sheet (speed / quality / subtitles / audio)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T) label,
  required T selected,
  required Future<void> Function(T) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black38,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        margin: const EdgeInsets.fromLTRB(
          PrysmDS.sp12,
          0,
          PrysmDS.sp12,
          PrysmDS.sp12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(PrysmDS.r16),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: PrysmDS.sp12),
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(PrysmDS.rFull),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PrysmDS.sp20,
                PrysmDS.sp16,
                PrysmDS.sp20,
                PrysmDS.sp8,
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: PrysmDS.textLg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: values.length,
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.paddingOf(context).bottom + PrysmDS.sp8,
                ),
                itemBuilder: (context, i) {
                  final value = values[i];
                  final isSelected = value == selected;
                  return _ChoiceItem(
                    label: label(value),
                    selected: isSelected,
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(onSelected(value));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChoiceItem extends StatefulWidget {
  const _ChoiceItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ChoiceItem> createState() => _ChoiceItemState();
}

class _ChoiceItemState extends State<_ChoiceItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: PrysmDS.fast,
        color: _pressed ? Colors.white.withAlpha(15) : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: PrysmDS.sp20,
          vertical: PrysmDS.sp14,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected ? Colors.white : Colors.white70,
                  fontSize: PrysmDS.textMd,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            if (widget.selected)
              const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: PrysmDS.iconMd,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────────────────────────────────────

String _fmt(Duration d) {
  final s = d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
  return '$m:${sec.toString().padLeft(2, '0')}';
}

bool _isDigitKey(LogicalKeyboardKey key) =>
    key.keyId >= LogicalKeyboardKey.digit0.keyId &&
    key.keyId <= LogicalKeyboardKey.digit9.keyId;

int? _digitValue(LogicalKeyboardKey key) {
  if (!_isDigitKey(key)) return null;
  return key.keyId - LogicalKeyboardKey.digit0.keyId;
}

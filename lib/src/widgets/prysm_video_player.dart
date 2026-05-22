import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/prysm_video_controller.dart';
import '../core/prysm_video_config.dart';
import '../core/prysm_video_event.dart';
import '../core/prysm_video_state.dart';
import '../customization/prysm_video_customization.dart';
import '../fullscreen/prysm_fullscreen.dart';
import '../theme/prysm_ds.dart';
import '../theme/prysm_video_theme.dart';
import '../thumbnails/prysm_seek_preview.dart';
import '../thumbnails/prysm_thumbnail_provider.dart';
import '../tracks/prysm_tracks.dart';
import 'prysm_video_surface.dart';

part '../controls/prysm_player_progress.dart';
part '../controls/prysm_player_settings.dart';

typedef PrysmVideoControlsBuilder =
    Widget Function(
      BuildContext context,
      PrysmVideoController controller,
      PrysmVideoState state,
    );

typedef PrysmVideoSurfaceBuilder =
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
    this.thumbnails,
    this.customization = const PrysmVideoCustomization(),
    this.surfaceBuilder,
  });

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;
  final PrysmVideoControlsBuilder? controls;
  final ValueChanged<PrysmVideoEvent>? onEvent;
  final PrysmVideoConfig? config;
  final PrysmVideoCustomization customization;
  final PrysmVideoSurfaceBuilder? surfaceBuilder;

  /// Optional seek-preview thumbnail configuration.
  ///
  /// When non-null, a thumbnail bubble appears above the progress bar while
  /// the user hovers (desktop), drags (mobile/desktop), or navigates (TV).
  /// See [PrysmThumbnailConfig] and its providers for setup details.
  final PrysmThumbnailConfig? thumbnails;

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
    KeyEventResult finish(KeyEventResult result) {
      final handler = widget.customization.keyboardShortcutHandler;
      if (handler == null) return result;
      final platform = context.playerPlatform(
        MediaQuery.sizeOf(context).width,
        widget.theme.density == PrysmControlsDensity.tv,
      );
      return handler(
        context,
        PrysmKeyboardShortcutDetails(
          context: _playerBuildContext(platform),
          event: event,
          defaultResult: result,
        ),
      );
    }

    if (!_config.enableKeyboard || event is! KeyDownEvent) {
      return finish(KeyEventResult.ignored);
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
      return finish(KeyEventResult.ignored);
    }
    _showControls();
    return finish(KeyEventResult.handled);
  }

  // ── Gestures ──────────────────────────────────────────────────────────────

  Offset? _doubleTapPos;

  void _handleDoubleTapDown(TapDownDetails d) =>
      _doubleTapPos = d.localPosition;

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
        customization: widget.customization,
        surfaceBuilder: widget.surfaceBuilder,
      ),
    );
  }

  PrysmPlayerBuildContext _playerBuildContext(PrysmPlayerPlatform platform) {
    return PrysmPlayerBuildContext(
      controller: _ctrl,
      state: _ctrl.state,
      config: _config,
      theme: widget.theme,
      platform: platform,
      visible: _controlsVisible,
      onInteraction: _showControls,
      onFullscreen: _config.enableFullscreen ? _enterFullscreen : null,
      thumbnails: widget.thumbnails,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final player = LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final platform = context.playerPlatform(
          constraints.maxWidth,
          widget.theme.density == PrysmControlsDensity.tv,
        );
        final details = _playerBuildContext(platform);
        final surface = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _config.enableGestures ? _toggleControls : null,
          onDoubleTapDown: _config.enableGestures ? _handleDoubleTapDown : null,
          onDoubleTap: _config.enableGestures
              ? () => _handleDoubleTap(size)
              : null,
          onVerticalDragUpdate: _config.enableGestures
              ? (d) => _handleVerticalDrag(d, size)
              : null,
          child: widget.surfaceBuilder == null
              ? PrysmVideoSurface(
                  controller: _ctrl,
                  fit: _config.fit,
                  aspectRatio: _config.aspectRatio,
                  pauseWhenBackgrounded: _config.pauseWhenBackgrounded,
                  resumeWhenForegrounded: _config.resumeWhenForegrounded,
                )
              : AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) =>
                      widget.surfaceBuilder!(context, _ctrl, _ctrl.state),
                ),
        );
        Widget interactiveChild = ColoredBox(
          color: widget.theme.backgroundColor,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // ── Video surface (isolated repaint boundary) ──────────
              surface,

              if (widget.customization.subtitleRendererBuilder != null)
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final current = _playerBuildContext(platform);
                    return widget.customization.subtitleRendererBuilder!(
                      context,
                      PrysmSubtitleRendererDetails(
                        context: current,
                        position: current.state.position,
                        selectedTrack: current.state.selectedTracks.subtitle,
                        subtitleStyle: widget.theme.subtitleStyle,
                      ),
                    );
                  },
                ),

              // ── Interactive controls overlay ───────────────────────
              if (_config.showControls)
                RepaintBoundary(
                  child: widget.controls != null
                      ? AnimatedBuilder(
                          animation: _ctrl,
                          builder: (context, _) =>
                              widget.controls!(context, _ctrl, _ctrl.state),
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
                          thumbnailConfig: widget.thumbnails,
                          customization: widget.customization,
                        ),
                ),

              // ── Always-visible state overlays ──────────────────────
              if (_config.showControls)
                _StateOverlay(
                  controller: _ctrl,
                  theme: widget.theme,
                  customization: widget.customization,
                  details: details,
                ),
            ],
          ),
        );

        final gestureBuilder = widget.customization.gestureBuilder;
        if (gestureBuilder != null) {
          interactiveChild = gestureBuilder(
            context,
            PrysmGestureDetails(context: details, child: interactiveChild),
          );
        }

        return MouseRegion(
          onHover: (_) => _showControls(),
          cursor: _controlsVisible || !_ctrl.state.fullscreen
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKey,
            child: interactiveChild,
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
  const _StateOverlay({
    required this.controller,
    required this.theme,
    required this.customization,
    required this.details,
  });

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;
  final PrysmVideoCustomization customization;
  final PrysmPlayerBuildContext details;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        if (state.error != null) {
          final defaultChild = _ErrorOverlay(
            controller: controller,
            state: state,
            theme: theme,
          );
          final builder = customization.errorBuilder;
          if (builder != null) {
            return Center(
              child: builder(
                context,
                PrysmErrorDetails(
                  context: details,
                  error: state.error,
                  retry: state.source == null
                      ? null
                      : () => unawaited(controller.open(state.source!)),
                  child: defaultChild,
                ),
              ),
            );
          }
          return Center(child: defaultChild);
        }
        if (state.buffering || state.status == PrysmPlaybackStatus.opening) {
          const defaultChild = _LoadingSpinner();
          final builder = customization.loadingBuilder;
          return Center(
            child: builder == null
                ? defaultChild
                : builder(
                    context,
                    PrysmLoadingDetails(context: details, child: defaultChild),
                  ),
          );
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
    required this.customization,
    this.thumbnailConfig,
  });

  final PrysmVideoController controller;
  final bool visible;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final ValueNotifier<_SeekDir?> seekDir;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;
  final PrysmVideoCustomization customization;
  final PrysmThumbnailConfig? thumbnailConfig;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isTv = theme.density == PrysmControlsDensity.tv;
        final platform = context.playerPlatform(width, isTv);
        final details = PrysmPlayerBuildContext(
          controller: controller,
          state: controller.state,
          config: config,
          theme: theme,
          platform: platform,
          visible: visible,
          onInteraction: onInteraction,
          onFullscreen: onFullscreen,
          thumbnails: thumbnailConfig,
        );

        final controls = switch (platform) {
          PrysmPlayerPlatform.tv => _TvControls(
            controller: controller,
            visible: visible,
            config: config,
            theme: theme,
            seekDir: seekDir,
            onInteraction: onInteraction,
            onFullscreen: onFullscreen,
            thumbnailConfig: thumbnailConfig,
            customization: customization,
            details: details,
          ),
          PrysmPlayerPlatform.mobile => _MobileControls(
            controller: controller,
            visible: visible,
            config: config,
            theme: theme,
            seekDir: seekDir,
            onInteraction: onInteraction,
            onFullscreen: onFullscreen,
            thumbnailConfig: thumbnailConfig,
            customization: customization,
            details: details,
          ),
          PrysmPlayerPlatform.desktop => _DesktopControls(
            controller: controller,
            visible: visible,
            config: config,
            theme: theme,
            seekDir: seekDir,
            onInteraction: onInteraction,
            onFullscreen: onFullscreen,
            thumbnailConfig: thumbnailConfig,
            customization: customization,
            details: details,
          ),
        };

        final builder = customization.controlsBuilder;
        if (builder == null) return controls;
        return builder(
          context,
          PrysmOverlayDetails(context: details, child: controls),
        );
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
    required this.customization,
    required this.details,
    this.thumbnailConfig,
  });

  final PrysmVideoController controller;
  final bool visible;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final ValueNotifier<_SeekDir?> seekDir;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;
  final PrysmVideoCustomization customization;
  final PrysmPlayerBuildContext details;
  final PrysmThumbnailConfig? thumbnailConfig;

  Widget buildTopBar(BuildContext context, Widget child) {
    final builder = customization.topBarBuilder;
    return builder == null
        ? child
        : builder(
            context,
            PrysmPlayerSectionDetails(context: details, child: child),
          );
  }

  Widget buildBottomBar(BuildContext context, Widget child) {
    final builder = customization.bottomBarBuilder;
    return builder == null
        ? child
        : builder(
            context,
            PrysmPlayerSectionDetails(context: details, child: child),
          );
  }

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
    required super.customization,
    required super.details,
    super.thumbnailConfig,
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
                    buildTopBar(
                      context,
                      _TopBar(
                        controller: controller,
                        theme: theme,
                        onInteraction: onInteraction,
                      ),
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
                    buildBottomBar(
                      context,
                      _BottomBar(
                        controller: controller,
                        config: config,
                        theme: theme,
                        onInteraction: onInteraction,
                        onFullscreen: onFullscreen,
                        thumbnailConfig: thumbnailConfig,
                        customization: customization,
                        details: details,
                        timeStyle: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: PrysmDS.textSm,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
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
    required super.customization,
    required super.details,
    super.thumbnailConfig,
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
                    buildTopBar(
                      context,
                      _TopBar(
                        controller: controller,
                        theme: theme,
                        onInteraction: onInteraction,
                      ),
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
                    buildBottomBar(
                      context,
                      _BottomBar(
                        controller: controller,
                        config: config,
                        theme: theme,
                        onInteraction: onInteraction,
                        onFullscreen: onFullscreen,
                        thumbnailConfig: thumbnailConfig,
                        customization: customization,
                        details: details,
                        timeStyle: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: PrysmDS.textMd,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
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
    required super.customization,
    required super.details,
    super.thumbnailConfig,
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
                    buildTopBar(
                      context,
                      _TopBar(
                        controller: controller,
                        theme: theme,
                        onInteraction: onInteraction,
                        titleFontSize: PrysmDS.textXl,
                      ),
                    ),
                    const Spacer(),
                    // TV: progress bar full width at bottom
                    _ProgressBar(
                      controller: controller,
                      theme: theme,
                      onInteraction: onInteraction,
                      thumbnailConfig: thumbnailConfig,
                      isTv: true,
                      customization: customization,
                      details: details,
                    ),
                    const SizedBox(height: PrysmDS.sp16),
                    Row(
                      children: <Widget>[
                        _TimeDisplay(controller: controller, theme: theme),
                        const Spacer(),
                        // TV action row — large buttons, focused navigation
                        _TvFocusHost(
                          customization: customization,
                          details: details,
                          child: _TvActionRow(
                            controller: controller,
                            config: config,
                            theme: theme,
                            onInteraction: onInteraction,
                            onFullscreen: onFullscreen,
                          ),
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
    required this.customization,
    required this.details,
    this.thumbnailConfig,
  });

  final PrysmVideoController controller;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;
  final TextStyle timeStyle;
  final PrysmVideoCustomization customization;
  final PrysmPlayerBuildContext details;
  final PrysmThumbnailConfig? thumbnailConfig;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ProgressBar(
          controller: controller,
          theme: theme,
          onInteraction: onInteraction,
          thumbnailConfig: thumbnailConfig,
          customization: customization,
          details: details,
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
              customization: customization,
              details: details,
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

class _TvFocusHost extends StatefulWidget {
  const _TvFocusHost({
    required this.customization,
    required this.details,
    required this.child,
  });

  final PrysmVideoCustomization customization;
  final PrysmPlayerBuildContext details;
  final Widget child;

  @override
  State<_TvFocusHost> createState() => _TvFocusHostState();
}

class _TvFocusHostState extends State<_TvFocusHost> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'PrysmVideoTvActions');
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = Focus(
      focusNode: _focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      child: widget.child,
    );
    final builder = widget.customization.tvFocusBuilder;
    if (builder == null) return child;
    return builder(
      context,
      PrysmTvFocusDetails(
        context: widget.details,
        child: child,
        focusNode: _focusNode,
        focused: _focused,
      ),
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
              ? Colors.white.withAlpha(61) // ~0.24
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
        child: Semantics(button: true, label: widget.tooltip, child: btn),
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

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar — interactive track + seek-preview overlay
// ─────────────────────────────────────────────────────────────────────────────

// Internal preview state carried by the ValueNotifier — updated without
// calling setState so only the preview overlay rebuilds on hover move.
class _SeekFeedback extends StatefulWidget {
  const _SeekFeedback({required this.notifier, required this.seconds});

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

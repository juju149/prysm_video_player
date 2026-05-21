import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'prysm_video_controller.dart';
import 'prysm_video_options.dart';
import 'prysm_video_source.dart';
import 'prysm_video_theme.dart';

class PrysmVideoPlayer extends StatefulWidget {
  const PrysmVideoPlayer({
    super.key,
    this.source,
    this.controller,
    this.options = const PrysmVideoOptions(),
    this.theme = const PrysmVideoTheme(),
    this.onReady,
    this.onError,
  }) : assert(source != null || controller != null);

  final PrysmVideoSource? source;
  final PrysmVideoController? controller;
  final PrysmVideoOptions options;
  final PrysmVideoTheme theme;
  final VoidCallback? onReady;
  final ValueChanged<String>? onError;

  @override
  State<PrysmVideoPlayer> createState() => _PrysmVideoPlayerState();
}

class _PrysmVideoPlayerState extends State<PrysmVideoPlayer> {
  late PrysmVideoController _controller;
  late bool _ownsController;
  final FocusNode _focusNode = FocusNode(debugLabel: 'PrysmVideoPlayer');
  Timer? _hideTimer;
  bool _controlsVisible = true;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _bindController();
    _openInitialSource();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant PrysmVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) {
        unawaited(_controller.dispose());
      }
      _bindController();
    }
    if (oldWidget.source != widget.source && widget.source != null) {
      unawaited(
        _controller.open(widget.source!, play: widget.options.autoPlay),
      );
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();
    if (_ownsController) {
      unawaited(_controller.dispose());
    }
    super.dispose();
  }

  void _bindController() {
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? PrysmVideoController(options: widget.options);
    _controller.addListener(_handleControllerChanged);
  }

  void _openInitialSource() {
    final source = widget.source;
    if (source == null) return;
    unawaited(
      _controller
          .open(source, play: widget.options.autoPlay)
          .then((_) => widget.onReady?.call()),
    );
  }

  void _handleControllerChanged() {
    final error = _controller.snapshot.error;
    if (error != null && error != _lastError) {
      _lastError = error;
      widget.onError?.call(error);
    }
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.options.autoHideControls || !widget.options.showControls) {
      return;
    }
    _hideTimer = Timer(widget.options.controlsAutoHideDelay, () {
      if (!mounted) return;
      if (_controller.snapshot.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (!widget.options.enableKeyboard || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      unawaited(_controller.toggle());
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_controller.seekRelative(-widget.options.seekStep));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(_controller.seekRelative(widget.options.seekStep));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      unawaited(_controller.setVolume(_controller.snapshot.volume + 5));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      unawaited(_controller.setVolume(_controller.snapshot.volume - 5));
    } else if (key == LogicalKeyboardKey.keyM) {
      unawaited(_controller.toggleMute());
    } else if (key == LogicalKeyboardKey.keyF &&
        widget.options.enableFullscreen) {
      unawaited(_enterFullscreen());
    } else {
      return KeyEventResult.ignored;
    }
    _showControls();
    return KeyEventResult.handled;
  }

  Future<void> _enterFullscreen() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) {
          return _FullscreenVideoPlayer(
            controller: _controller,
            options: widget.options,
            theme: widget.theme,
          );
        },
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = MouseRegion(
      onHover: (_) => _showControls(),
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.options.enableGestures ? _toggleControls : null,
          onDoubleTap: widget.options.enableGestures
              ? () => unawaited(_controller.toggle())
              : null,
          child: DecoratedBox(
            decoration: BoxDecoration(color: widget.theme.backgroundColor),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Video(
                  controller: _controller.videoController,
                  fit: widget.options.fit,
                  aspectRatio: widget.options.aspectRatio,
                  controls: null,
                  pauseUponEnteringBackgroundMode:
                      widget.options.pauseWhenBackgrounded,
                  resumeUponEnteringForegroundMode:
                      widget.options.resumeWhenForegrounded,
                ),
                if (widget.options.showControls)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return _PrysmControls(
                        controller: _controller,
                        snapshot: _controller.snapshot,
                        visible: _controlsVisible,
                        options: widget.options,
                        theme: widget.theme,
                        onInteraction: _showControls,
                        onFullscreen: widget.options.enableFullscreen
                            ? _enterFullscreen
                            : null,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final aspectRatio = widget.options.aspectRatio;
    if (aspectRatio == null) return player;
    return AspectRatio(aspectRatio: aspectRatio, child: player);
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  const _FullscreenVideoPlayer({
    required this.controller,
    required this.options,
    required this.theme,
  });

  final PrysmVideoController controller;
  final PrysmVideoOptions options;
  final PrysmVideoTheme theme;

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PrysmVideoPlayer(
          controller: widget.controller,
          options: widget.options.copyWith(
            aspectRatio: null,
            enableFullscreen: false,
          ),
          theme: widget.theme,
        ),
      ),
    );
  }
}

class _PrysmControls extends StatelessWidget {
  const _PrysmControls({
    required this.controller,
    required this.snapshot,
    required this.visible,
    required this.options,
    required this.theme,
    required this.onInteraction,
    required this.onFullscreen,
  });

  final PrysmVideoController controller;
  final PrysmVideoSnapshot snapshot;
  final bool visible;
  final PrysmVideoOptions options;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < theme.compactBreakpoint;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.scrimColor, Colors.transparent, theme.scrimColor],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(compact ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(
                    title: options.title,
                    subtitle: options.subtitle,
                    theme: theme,
                    onClose: Navigator.of(context).canPop()
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  const Spacer(),
                  Center(
                    child: _CenterControls(
                      controller: controller,
                      snapshot: snapshot,
                      options: options,
                      theme: theme,
                      compact: compact,
                      onInteraction: onInteraction,
                    ),
                  ),
                  const Spacer(),
                  _BottomBar(
                    controller: controller,
                    snapshot: snapshot,
                    options: options,
                    theme: theme,
                    compact: compact,
                    onInteraction: onInteraction,
                    onFullscreen: onFullscreen,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onClose,
  });

  final String? title;
  final String? subtitle;
  final PrysmVideoTheme theme;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onClose != null)
          _RoundButton(
            icon: Icons.close_rounded,
            theme: theme,
            onTap: onClose!,
          ),
        if (title != null || subtitle != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.secondaryColor, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CenterControls extends StatelessWidget {
  const _CenterControls({
    required this.controller,
    required this.snapshot,
    required this.options,
    required this.theme,
    required this.compact,
    required this.onInteraction,
  });

  final PrysmVideoController controller;
  final PrysmVideoSnapshot snapshot;
  final PrysmVideoOptions options;
  final PrysmVideoTheme theme;
  final bool compact;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          icon: Icons.replay_10_rounded,
          theme: theme,
          size: compact ? 46 : 56,
          onTap: () {
            onInteraction();
            unawaited(controller.seekRelative(-options.seekStep));
          },
        ),
        SizedBox(width: compact ? 18 : 28),
        _RoundButton(
          icon: snapshot.playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          theme: theme,
          size: compact ? 68 : 84,
          iconSize: compact ? 42 : 54,
          onTap: () {
            onInteraction();
            unawaited(controller.toggle());
          },
        ),
        SizedBox(width: compact ? 18 : 28),
        _RoundButton(
          icon: Icons.forward_10_rounded,
          theme: theme,
          size: compact ? 46 : 56,
          onTap: () {
            onInteraction();
            unawaited(controller.seekRelative(options.seekStep));
          },
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.controller,
    required this.snapshot,
    required this.options,
    required this.theme,
    required this.compact,
    required this.onInteraction,
    required this.onFullscreen,
  });

  final PrysmVideoController controller;
  final PrysmVideoSnapshot snapshot;
  final PrysmVideoOptions options;
  final PrysmVideoTheme theme;
  final bool compact;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;

  @override
  Widget build(BuildContext context) {
    final position = snapshot.position;
    final duration = snapshot.duration;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: theme.accentColor,
            inactiveTrackColor: theme.trackColor,
            secondaryActiveTrackColor: theme.bufferColor,
            thumbColor: theme.accentColor,
          ),
          child: Slider(
            value: _durationRatio(position, duration),
            secondaryTrackValue: snapshot.bufferProgress,
            onChanged: (value) {
              onInteraction();
              if (duration > Duration.zero) {
                unawaited(controller.seek(duration * value));
              }
            },
          ),
        ),
        Row(
          children: [
            Text(
              '${_formatDuration(position)} / ${_formatDuration(duration)}',
              style: TextStyle(color: theme.secondaryColor, fontSize: 12),
            ),
            const Spacer(),
            if (!compact) ...[
              _RateMenu(
                controller: controller,
                snapshot: snapshot,
                theme: theme,
              ),
              const SizedBox(width: 8),
            ],
            _RoundButton(
              icon: snapshot.muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              theme: theme,
              compact: true,
              onTap: () {
                onInteraction();
                unawaited(controller.toggleMute());
              },
            ),
            if (onFullscreen != null) ...[
              const SizedBox(width: 8),
              _RoundButton(
                icon: Icons.fullscreen_rounded,
                theme: theme,
                compact: true,
                onTap: () {
                  onInteraction();
                  unawaited(onFullscreen!());
                },
              ),
            ],
          ],
        ),
        if (snapshot.buffering)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: theme.accentColor,
              backgroundColor: Colors.transparent,
            ),
          ),
        if (snapshot.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              snapshot.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.errorColor, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _RateMenu extends StatelessWidget {
  const _RateMenu({
    required this.controller,
    required this.snapshot,
    required this.theme,
  });

  final PrysmVideoController controller;
  final PrysmVideoSnapshot snapshot;
  final PrysmVideoTheme theme;

  @override
  Widget build(BuildContext context) {
    const rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      color: const Color(0xFF151515),
      onSelected: (value) => unawaited(controller.setRate(value)),
      itemBuilder: (context) => [
        for (final rate in rates)
          PopupMenuItem(
            value: rate,
            child: Text(
              '${rate}x',
              style: TextStyle(
                color: rate == snapshot.rate
                    ? theme.primaryColor
                    : theme.secondaryColor,
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          '${snapshot.rate.toStringAsFixed(snapshot.rate == 1 ? 0 : 2)}x',
          style: TextStyle(color: theme.primaryColor, fontSize: 12),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.theme,
    required this.onTap,
    this.size = 40,
    this.iconSize = 24,
    this.compact = false,
  });

  final IconData icon;
  final PrysmVideoTheme theme;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = compact ? 34.0 : size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: SizedBox(
          width: resolvedSize,
          height: resolvedSize,
          child: Icon(icon, color: theme.primaryColor, size: iconSize),
        ),
      ),
    );
  }
}

double _durationRatio(Duration position, Duration duration) {
  if (duration <= Duration.zero) return 0;
  return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/prysm_video_controller.dart';
import '../core/prysm_video_config.dart';
import '../core/prysm_video_event.dart';
import '../core/prysm_video_state.dart';
import '../fullscreen/prysm_fullscreen.dart';
import '../theme/prysm_video_theme.dart';
import '../tracks/prysm_tracks.dart';
import 'prysm_video_surface.dart';

typedef PrysmVideoControlsBuilder =
    Widget Function(
      BuildContext context,
      PrysmVideoController controller,
      PrysmVideoState state,
    );

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
  late StreamSubscription<PrysmVideoEvent> _eventSubscription;
  final FocusNode _focusNode = FocusNode(debugLabel: 'PrysmVideoPlayer');
  Timer? _hideTimer;
  bool _controlsVisible = true;
  Offset? _doubleTapPosition;

  PrysmVideoController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? widget.controller.config;
    _eventSubscription = widget.controller.events.listen(
      (e) => widget.onEvent?.call(e),
    );
    if (widget.controller.source != null &&
        widget.controller.state.status == PrysmPlaybackStatus.idle) {
      unawaited(widget.controller.open(widget.controller.source!));
    }
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant PrysmVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _eventSubscription.cancel();
      _eventSubscription = widget.controller.events.listen(
        (e) => widget.onEvent?.call(e),
      );
    }
    _config = widget.config ?? widget.controller.config;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();
    unawaited(_eventSubscription.cancel());
    super.dispose();
  }

  void _showControls() {
    if (!_controlsVisible && mounted) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controller.state.controlsLocked) return;
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_config.autoHideControls || !_config.showControls) return;
    _hideTimer = Timer(_config.controlsAutoHideDelay, () {
      if (!mounted) return;
      if (_controller.state.playing && !_controller.state.controlsLocked) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (!_config.enableKeyboard || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      unawaited(_controller.toggle());
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_controller.seekBy(-_config.seekStep));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(_controller.seekBy(_config.seekStep));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      unawaited(_controller.setVolume(_controller.state.volume + 5));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      unawaited(_controller.setVolume(_controller.state.volume - 5));
    } else if (key == LogicalKeyboardKey.keyM) {
      unawaited(_controller.toggleMute());
    } else if (key == LogicalKeyboardKey.keyF && _config.enableFullscreen) {
      unawaited(_enterFullscreen());
    } else if (key == LogicalKeyboardKey.escape &&
        _controller.state.fullscreen) {
      Navigator.of(context).maybePop();
    } else if (_isDigitKey(key)) {
      final digit = _digitValue(key);
      if (digit != null && _controller.state.duration > Duration.zero) {
        unawaited(
          _controller.seekTo(_controller.state.duration * (digit / 10)),
        );
      }
    } else {
      return KeyEventResult.ignored;
    }
    _showControls();
    return KeyEventResult.handled;
  }

  Future<void> _enterFullscreen() async {
    await Navigator.of(context).push(
      PrysmFullscreenRoute(
        controller: _controller,
        config: _config,
        theme: widget.theme,
      ),
    );
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _handleDoubleTap(Size size) {
    final dx = _doubleTapPosition?.dx ?? size.width / 2;
    if (dx < size.width * 0.4) {
      unawaited(_controller.seekBy(-_config.seekStep));
    } else if (dx > size.width * 0.6) {
      unawaited(_controller.seekBy(_config.seekStep));
    } else {
      unawaited(_controller.toggle());
    }
    HapticFeedback.selectionClick();
    _showControls();
  }

  void _handleVerticalDrag(DragUpdateDetails details, Size size) {
    if (!_config.enableGestures || size.width <= 0) return;
    if (details.localPosition.dx < size.width / 2) return;
    final delta = -details.delta.dy / 2;
    unawaited(_controller.setVolume(_controller.state.volume + delta));
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final player = LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onHover: (_) => _showControls(),
          cursor: _controlsVisible || !_controller.state.fullscreen
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKeyEvent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _config.enableGestures ? _toggleControls : null,
              onDoubleTapDown: _config.enableGestures
                  ? _handleDoubleTapDown
                  : null,
              onDoubleTap: _config.enableGestures
                  ? () => _handleDoubleTap(size)
                  : null,
              onVerticalDragUpdate: _config.enableGestures
                  ? (details) => _handleVerticalDrag(details, size)
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(color: widget.theme.backgroundColor),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    PrysmVideoSurface(
                      controller: _controller,
                      fit: _config.fit,
                      aspectRatio: _config.aspectRatio,
                      pauseWhenBackgrounded: _config.pauseWhenBackgrounded,
                      resumeWhenForegrounded: _config.resumeWhenForegrounded,
                    ),
                    if (_config.showControls)
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final state = _controller.state;
                          if (widget.controls != null) {
                            return widget.controls!(
                              context,
                              _controller,
                              state,
                            );
                          }
                          return _PremiumControls(
                            controller: _controller,
                            state: state,
                            visible: _controlsVisible,
                            config: _config,
                            theme: widget.theme,
                            onInteraction: _showControls,
                            onFullscreen: _config.enableFullscreen
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
      },
    );

    final aspectRatio = _config.aspectRatio;
    if (aspectRatio == null) return player;
    return AspectRatio(aspectRatio: aspectRatio, child: player);
  }
}

class _PremiumControls extends StatelessWidget {
  const _PremiumControls({
    required this.controller,
    required this.state,
    required this.visible,
    required this.config,
    required this.theme,
    required this.onInteraction,
    required this.onFullscreen,
  });

  final PrysmVideoController controller;
  final PrysmVideoState state;
  final bool visible;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < theme.compactBreakpoint;
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
              colors: <Color>[
                theme.scrimColor,
                Colors.transparent,
                theme.scrimColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(compact ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _TopBar(state: state, theme: theme),
                  const Spacer(),
                  Center(
                    child: _CenterControls(
                      controller: controller,
                      state: state,
                      config: config,
                      theme: theme,
                      compact: compact,
                      onInteraction: onInteraction,
                    ),
                  ),
                  const Spacer(),
                  _BottomBar(
                    controller: controller,
                    state: state,
                    config: config,
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
  const _TopBar({required this.state, required this.theme});

  final PrysmVideoState state;
  final PrysmVideoTheme theme;

  @override
  Widget build(BuildContext context) {
    final source = state.source;
    return Row(
      children: <Widget>[
        if (Navigator.of(context).canPop())
          _IconButton(
            icon: Icons.close_rounded,
            tooltip: theme.labels.exitFullscreen,
            theme: theme,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        if (source?.title != null || source?.subtitle != null) ...<Widget>[
          const SizedBox(width: 12),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (source?.subtitle != null)
                  Text(
                    source!.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.secondaryColor, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
        if (state.live)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                theme.labels.live.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CenterControls extends StatelessWidget {
  const _CenterControls({
    required this.controller,
    required this.state,
    required this.config,
    required this.theme,
    required this.compact,
    required this.onInteraction,
  });

  final PrysmVideoController controller;
  final PrysmVideoState state;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final bool compact;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return _ErrorOverlay(controller: controller, state: state, theme: theme);
    }
    if (state.buffering || state.status == PrysmPlaybackStatus.opening) {
      return _LoadingOverlay(theme: theme);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _IconButton(
          icon: Icons.replay_10_rounded,
          tooltip: 'Replay 10 seconds',
          theme: theme,
          size: compact ? 46 : 56,
          onTap: () {
            onInteraction();
            unawaited(controller.seekBy(-config.seekStep));
          },
        ),
        SizedBox(width: compact ? 18 : 28),
        _IconButton(
          icon: state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: state.playing ? theme.labels.pause : theme.labels.play,
          theme: theme,
          size: compact ? 68 : 84,
          iconSize: compact ? 42 : 54,
          onTap: () {
            onInteraction();
            unawaited(controller.toggle());
          },
        ),
        SizedBox(width: compact ? 18 : 28),
        _IconButton(
          icon: Icons.forward_10_rounded,
          tooltip: 'Forward 10 seconds',
          theme: theme,
          size: compact ? 46 : 56,
          onTap: () {
            onInteraction();
            unawaited(controller.seekBy(config.seekStep));
          },
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.controller,
    required this.state,
    required this.config,
    required this.theme,
    required this.compact,
    required this.onInteraction,
    required this.onFullscreen,
  });

  final PrysmVideoController controller;
  final PrysmVideoState state;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final bool compact;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: compact ? 3 : 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: theme.accentColor,
            inactiveTrackColor: theme.trackColor,
            secondaryActiveTrackColor: theme.bufferColor,
            thumbColor: theme.accentColor,
          ),
          child: Slider(
            value: state.progress,
            secondaryTrackValue: state.bufferProgress,
            onChanged: state.duration <= Duration.zero
                ? null
                : (value) {
                    onInteraction();
                    unawaited(controller.seekTo(state.duration * value));
                  },
          ),
        ),
        Row(
          children: <Widget>[
            Text(
              state.live
                  ? theme.labels.live
                  : '${_formatDuration(state.position)} / ${_formatDuration(state.duration)}',
              style: TextStyle(color: theme.secondaryColor, fontSize: 12),
            ),
            const Spacer(),
            if (!compact) ...<Widget>[
              _SettingsMenu(controller: controller, state: state, theme: theme),
              const SizedBox(width: 8),
            ],
            _IconButton(
              icon: state.muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              tooltip: state.muted ? 'Unmute' : 'Mute',
              theme: theme,
              compact: true,
              onTap: () {
                onInteraction();
                unawaited(controller.toggleMute());
              },
            ),
            if (config.enablePictureInPicture) ...<Widget>[
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.picture_in_picture_alt_rounded,
                tooltip: theme.labels.pictureInPicture,
                theme: theme,
                compact: true,
                onTap: () {
                  onInteraction();
                  unawaited(controller.enablePictureInPicture());
                },
              ),
            ],
            if (onFullscreen != null) ...<Widget>[
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.fullscreen_rounded,
                tooltip: theme.labels.fullscreen,
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
      ],
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu({
    required this.controller,
    required this.state,
    required this.theme,
  });

  final PrysmVideoController controller;
  final PrysmVideoState state;
  final PrysmVideoTheme theme;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      tooltip: theme.labels.settings,
      color: const Color(0xFF151515),
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) => <PopupMenuEntry<_MenuAction>>[
        PopupMenuItem<_MenuAction>(
          value: const _MenuAction.speed(1.0),
          child: Text(
            '${theme.labels.speed}: ${state.speed.toStringAsFixed(state.speed == 1 ? 0 : 2)}x',
            style: TextStyle(color: theme.primaryColor),
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.quality(state.selectedQuality),
          child: Text(
            '${theme.labels.quality}: ${state.selectedQuality.label}',
            style: TextStyle(color: theme.primaryColor),
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.subtitle(state.selectedTracks.subtitle.id),
          child: Text(
            '${theme.labels.subtitles}: ${state.selectedTracks.subtitle.label}',
            style: TextStyle(color: theme.primaryColor),
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.audio(state.selectedTracks.audio.id),
          child: Text(
            '${theme.labels.audio}: ${state.selectedTracks.audio.label}',
            style: TextStyle(color: theme.primaryColor),
          ),
        ),
      ],
      child: _IconButtonVisual(
        icon: Icons.settings_rounded,
        theme: theme,
        compact: true,
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, _MenuAction action) async {
    switch (action.kind) {
      case _MenuActionKind.speed:
        await _showSpeedSheet(context);
      case _MenuActionKind.quality:
        await _showQualitySheet(context);
      case _MenuActionKind.subtitle:
        await _showSubtitleSheet(context);
      case _MenuActionKind.audio:
        await _showAudioSheet(context);
    }
  }

  Future<void> _showSpeedSheet(BuildContext context) {
    const speeds = <double>[0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3];
    return _showChoiceSheet<double>(
      context,
      title: theme.labels.speed,
      values: speeds,
      label: (value) => '${value}x',
      selected: state.speed,
      onSelected: controller.setSpeed,
    );
  }

  Future<void> _showQualitySheet(BuildContext context) {
    return _showChoiceSheet<PrysmVideoQuality>(
      context,
      title: theme.labels.quality,
      values: state.availableQualities,
      label: (value) => value.label,
      selected: state.selectedQuality,
      onSelected: controller.selectVideoQuality,
    );
  }

  Future<void> _showSubtitleSheet(BuildContext context) {
    return _showChoiceSheet<PrysmSubtitleTrackInfo>(
      context,
      title: theme.labels.subtitles,
      values: state.availableTracks.subtitles,
      label: (value) => value.label,
      selected: state.selectedTracks.subtitle,
      onSelected: (value) => controller.selectSubtitleTrack(value.id),
    );
  }

  Future<void> _showAudioSheet(BuildContext context) {
    return _showChoiceSheet<PrysmAudioTrack>(
      context,
      title: theme.labels.audio,
      values: state.availableTracks.audio,
      label: (value) => value.label,
      selected: state.selectedTracks.audio,
      onSelected: (value) => controller.selectAudioTrack(value.id),
    );
  }
}

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: theme.errorColor,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              error?.userMessage ?? 'The video could not be played.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.source == null
                  ? null
                  : () => unawaited(controller.open(state.source!)),
              child: Text(theme.labels.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.theme});

  final PrysmVideoTheme theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: theme.labels.buffering,
      child: SizedBox.square(
        dimension: 42,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: theme.accentColor,
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.theme,
    required this.onTap,
    this.size = 40,
    this.iconSize = 24,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final PrysmVideoTheme theme;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: _IconButtonVisual(
            icon: icon,
            theme: theme,
            size: size,
            iconSize: iconSize,
            compact: compact,
          ),
        ),
      ),
    );
  }
}

class _IconButtonVisual extends StatelessWidget {
  const _IconButtonVisual({
    required this.icon,
    required this.theme,
    this.size = 40,
    this.iconSize = 24,
    this.compact = false,
  });

  final IconData icon;
  final PrysmVideoTheme theme;
  final double size;
  final double iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = compact ? 36.0 : size;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(resolvedSize / 2),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: SizedBox(
        width: resolvedSize,
        height: resolvedSize,
        child: Icon(icon, color: theme.primaryColor, size: iconSize),
      ),
    );
  }
}

Future<void> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T value) label,
  required T selected,
  required Future<void> Function(T value) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF151515),
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final value in values)
              ListTile(
                title: Text(
                  label(value),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: value == selected
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(onSelected(value));
                },
              ),
          ],
        ),
      );
    },
  );
}

bool _isDigitKey(LogicalKeyboardKey key) {
  return key.keyId >= LogicalKeyboardKey.digit0.keyId &&
      key.keyId <= LogicalKeyboardKey.digit9.keyId;
}

int? _digitValue(LogicalKeyboardKey key) {
  if (!_isDigitKey(key)) return null;
  return key.keyId - LogicalKeyboardKey.digit0.keyId;
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

enum _MenuActionKind { speed, quality, subtitle, audio }

class _MenuAction {
  const _MenuAction.speed(this.value)
    : kind = _MenuActionKind.speed,
      assert(value is double);
  const _MenuAction.quality(this.value)
    : kind = _MenuActionKind.quality,
      assert(value is PrysmVideoQuality);
  const _MenuAction.subtitle(this.value)
    : kind = _MenuActionKind.subtitle,
      assert(value is String);
  const _MenuAction.audio(this.value)
    : kind = _MenuActionKind.audio,
      assert(value is String);

  final _MenuActionKind kind;
  final Object value;
}

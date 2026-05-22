part of '../widgets/prysm_video_player.dart';

class _SeekPreviewState {
  const _SeekPreviewState({
    this.visible = false,
    this.progress = 0.0,
    this.timestamp = Duration.zero,
    this.result,
    this.loading = false,
  });

  final bool visible;
  final double progress;
  final Duration timestamp;
  final PrysmThumbnailResult? result;
  final bool loading;

  _SeekPreviewState copyWith({
    bool? visible,
    double? progress,
    Duration? timestamp,
    PrysmThumbnailResult? result,
    bool clearResult = false,
    bool? loading,
  }) {
    return _SeekPreviewState(
      visible: visible ?? this.visible,
      progress: progress ?? this.progress,
      timestamp: timestamp ?? this.timestamp,
      result: clearResult ? null : (result ?? this.result),
      loading: loading ?? this.loading,
    );
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({
    required this.controller,
    required this.theme,
    required this.onInteraction,
    required this.customization,
    required this.details,
    this.thumbnailConfig,
    this.isTv = false,
  });

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;
  final PrysmVideoCustomization customization;
  final PrysmPlayerBuildContext details;

  /// Optional thumbnail configuration. When null, no preview is shown.
  final PrysmThumbnailConfig? thumbnailConfig;

  /// When true, uses TV-sized preview bubbles.
  final bool isTv;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  // ── Existing track state ──────────────────────────────────────────────────
  bool _hovering = false;
  bool _dragging = false;
  double? _dragProgress;
  late AnimationController _hoverCtrl;
  late Animation<double> _trackH;
  late Animation<double> _thumbOp;

  // ── Preview state ─────────────────────────────────────────────────────────
  // Updated without setState to avoid unnecessary CustomPaint rebuilds.
  final ValueNotifier<_SeekPreviewState> _previewNotifier = ValueNotifier(
    const _SeekPreviewState(),
  );
  final PrysmThumbnailCache _thumbCache = PrysmThumbnailCache();
  Timer? _thumbTimer;
  PrysmThumbnailResult? _lastResult;
  bool _previewActive = false;
  bool _disposed = false;

  // Stored to detect source changes and invalidate the cache.
  Object? _lastSourceId;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(vsync: this, duration: PrysmDS.fast);
    _trackH = Tween<double>(
      begin: PrysmDS.trackIdle,
      end: PrysmDS.trackActive,
    ).animate(CurvedAnimation(parent: _hoverCtrl, curve: PrysmDS.curveOut));
    _thumbOp = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _hoverCtrl, curve: PrysmDS.curveOut));
    _lastSourceId = widget.controller.state.source?.uri;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _disposed = true;
    widget.controller.removeListener(_onControllerChanged);
    _thumbTimer?.cancel();
    _previewNotifier.dispose();
    _hoverCtrl.dispose();
    super.dispose();
  }

  // ── Source change detection ───────────────────────────────────────────────

  void _onControllerChanged() {
    final newId = widget.controller.state.source?.uri;
    if (newId != _lastSourceId) {
      _lastSourceId = newId;
      _thumbCache.clear();
      _lastResult = null;
      widget.thumbnailConfig?.provider?.dispose();
    }
  }

  // ── Track animation helpers ───────────────────────────────────────────────

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

  // ── Preview management ────────────────────────────────────────────────────

  void _showPreview(double progress) {
    final cfg = widget.thumbnailConfig;
    if (cfg == null || _disposed) return;

    final dur = widget.controller.state.duration;
    final ts = dur > Duration.zero ? dur * progress : Duration.zero;

    _previewActive = true;
    _previewNotifier.value = _SeekPreviewState(
      visible: true,
      progress: progress,
      timestamp: ts,
      // Show last cached result while the new one resolves — prevents flicker.
      result: _lastResult,
      loading: cfg.provider != null && dur > Duration.zero,
    );

    _thumbTimer?.cancel();
    if (cfg.provider != null && dur > Duration.zero) {
      _thumbTimer = Timer(cfg.throttle, () => _resolveThumb(progress, ts, dur));
    }
  }

  void _hidePreview() {
    if (!_previewActive || _disposed) return;
    _previewActive = false;
    _thumbTimer?.cancel();
    _previewNotifier.value = _previewNotifier.value.copyWith(visible: false);
  }

  Future<void> _resolveThumb(double progress, Duration ts, Duration dur) async {
    try {
      final provider = widget.thumbnailConfig?.provider;
      if (provider == null || !mounted || _disposed) return;

      // Quantise to 200 ms buckets so adjacent positions share cached results.
      final cacheKey = (ts.inMilliseconds ~/ 200) * 200;
      final cached = _thumbCache.get(cacheKey);
      if (cached != null) {
        _lastResult = cached;
        if (!mounted || _disposed) return;
        if (_previewActive) {
          _previewNotifier.value = _previewNotifier.value.copyWith(
            result: cached,
            loading: false,
          );
        }
        return;
      }

      final result = await provider.resolve(ts, dur);
      if (!mounted || _disposed || result == null) return;

      _thumbCache.put(cacheKey, result);
      _lastResult = result;

      if (_previewActive) {
        _previewNotifier.value = _previewNotifier.value.copyWith(
          result: result,
          loading: false,
        );
      }
    } catch (_) {
      // Thumbnail resolution failed (network error, invalid URL, etc.).
      // Silently swallow — the timecode fallback is already displayed.
    }
  }

  // ── Layout helpers ────────────────────────────────────────────────────────

  double _calcPreviewLeft(double progress, double barWidth) {
    final cfg = widget.thumbnailConfig!;
    final pw = widget.isTv ? cfg.tvPreviewWidth : cfg.previewWidth;
    if (!cfg.hasImages) {
      // Timecode-only: use a fixed narrow width estimate (~64px).
      const narrowW = 64.0;
      return (barWidth * progress - narrowW / 2).clamp(
        0.0,
        (barWidth - narrowW).clamp(0.0, double.infinity),
      );
    }
    return (barWidth * progress - pw / 2).clamp(
      0.0,
      (barWidth - pw).clamp(0.0, double.infinity),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasThumbnails = widget.thumbnailConfig != null;

    final defaultBar = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // ── Interactive track ─────────────────────────────────────────────
        final track = MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            setState(() => _hovering = true);
            _activate();
          },
          onHover: hasThumbnails
              ? (event) {
                  final p = (event.localPosition.dx / width).clamp(0.0, 1.0);
                  _showPreview(p);
                }
              : null,
          onExit: (_) {
            setState(() => _hovering = false);
            _deactivate();
            if (!_dragging) _hidePreview();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final p = (d.localPosition.dx / width).clamp(0.0, 1.0);
              _commitSeek(p);
              if (!_hovering) _hidePreview();
            },
            onHorizontalDragStart: (d) {
              final p = (d.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() {
                _dragging = true;
                _dragProgress = p;
              });
              _activate();
              if (hasThumbnails) {
                _showPreview(p);
                HapticFeedback.selectionClick();
              }
              widget.onInteraction();
            },
            onHorizontalDragUpdate: (d) {
              final p = (d.localPosition.dx / width).clamp(0.0, 1.0);
              setState(() => _dragProgress = p);
              if (hasThumbnails) _showPreview(p);
            },
            onHorizontalDragEnd: (_) {
              if (_dragProgress != null) _commitSeek(_dragProgress!);
              setState(() {
                _dragging = false;
                _dragProgress = null;
              });
              _deactivate();
              if (!_hovering) _hidePreview();
            },
            child: SizedBox(
              height: 28,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  widget.controller,
                  _hoverCtrl,
                ]),
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
          ),
        );

        if (!hasThumbnails) return track;

        // ── Preview overlay ───────────────────────────────────────────────
        // Stack with Clip.none lets the bubble float above the 28 px hit area
        // without being clipped by the progress-bar's own paint bounds.
        // Since the controls layout already fills the full player height, the
        // bubble stays within the player's visual bounds.
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            track,
            ValueListenableBuilder<_SeekPreviewState>(
              valueListenable: _previewNotifier,
              builder: (context, state, _) {
                final left = _calcPreviewLeft(state.progress, width);
                return Positioned(
                  // Position the bubble bottom edge ~36 px above the track
                  // area bottom, giving a comfortable gap above the thumb.
                  bottom: 36,
                  left: left,
                  child: IgnorePointer(
                    child: AnimatedScale(
                      scale: state.visible ? 1.0 : 0.88,
                      duration: state.visible ? PrysmDS.fast : PrysmDS.standard,
                      curve: PrysmDS.curveOut,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedOpacity(
                        opacity: state.visible ? 1.0 : 0.0,
                        duration: state.visible
                            ? PrysmDS.fast
                            : PrysmDS.standard,
                        curve: PrysmDS.curveOut,
                        child: PrysmSeekPreview(
                          data: SeekPreviewData(
                            visible: state.visible,
                            progress: state.progress,
                            timestamp: state.timestamp,
                            result: state.result,
                            loading: state.loading,
                          ),
                          config: widget.thumbnailConfig!,
                          theme: widget.theme,
                          isTv: widget.isTv,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
    final builder = widget.customization.progressBarBuilder;
    if (builder == null) return defaultBar;
    return builder(
      context,
      PrysmProgressBarDetails(
        context: widget.details,
        isTv: widget.isTv,
        child: defaultBar,
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

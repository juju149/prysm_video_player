import 'package:flutter/material.dart';

import '../theme/prysm_ds.dart';
import '../theme/prysm_video_theme.dart';
import 'prysm_thumbnail_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal state data class (shared between progress bar and preview widget)
// ─────────────────────────────────────────────────────────────────────────────

/// State passed from [_ProgressBar] to [PrysmSeekPreview] via ValueNotifier.
class SeekPreviewData {
  const SeekPreviewData({
    required this.visible,
    required this.progress,
    required this.timestamp,
    this.result,
    this.loading = false,
  });

  /// Whether the preview should be shown.
  final bool visible;

  /// Seek progress 0–1 (used for positioning the bubble above the bar).
  final double progress;

  /// The video timestamp this preview corresponds to.
  final Duration timestamp;

  /// Resolved thumbnail (null = loading or no provider).
  final PrysmThumbnailResult? result;

  /// True while the thumbnail is being resolved after a throttle delay.
  final bool loading;

  SeekPreviewData copyWith({
    bool? visible,
    double? progress,
    Duration? timestamp,
    PrysmThumbnailResult? result,
    bool clearResult = false,
    bool? loading,
  }) {
    return SeekPreviewData(
      visible: visible ?? this.visible,
      progress: progress ?? this.progress,
      timestamp: timestamp ?? this.timestamp,
      result: clearResult ? null : (result ?? this.result),
      loading: loading ?? this.loading,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public preview widget
// ─────────────────────────────────────────────────────────────────────────────

/// The floating seek-preview bubble shown above the progress bar.
///
/// Renders:
/// - A thumbnail image (full or sprite-cropped), or a subtle loading spinner.
/// - A timecode label with tabular figures.
/// - A premium dark-glass container with shadow and border.
///
/// Callers are responsible for positioning and animating the opacity/scale.
class PrysmSeekPreview extends StatelessWidget {
  const PrysmSeekPreview({
    super.key,
    required this.data,
    required this.config,
    required this.theme,
    this.isTv = false,
  });

  final SeekPreviewData data;
  final PrysmThumbnailConfig config;
  final PrysmVideoTheme theme;

  /// When true, uses [PrysmThumbnailConfig.tvPreviewWidth/Height] and larger
  /// typography, for comfortable reading at a distance.
  final bool isTv;

  double get _w => isTv ? config.tvPreviewWidth : config.previewWidth;
  double get _h => isTv ? config.tvPreviewHeight : config.previewHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: config.hasImages ? _w : null,
      constraints: config.hasImages ? null : const BoxConstraints(minWidth: 64),
      decoration: BoxDecoration(
        color: const Color(0xEA0D0D0D),
        borderRadius: BorderRadius.circular(PrysmDS.r8),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x60000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Color.fromRGBO(255, 255, 255, 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (config.hasImages) _buildImageSection(),
          _buildTimecodeSection(),
        ],
      ),
    );
  }

  // ── Image section ─────────────────────────────────────────────────────────

  Widget _buildImageSection() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(PrysmDS.r8 - 0.5),
      ),
      child: SizedBox(width: _w, height: _h, child: _buildImageContent()),
    );
  }

  Widget _buildImageContent() {
    final result = data.result;

    if (result == null) {
      return const _LoadingPlaceholder();
    }

    if (result.sourceRect == null) {
      // Full image (list strategy)
      return Image(
        image: result.image,
        width: _w,
        height: _h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _LoadingPlaceholder(),
      );
    }

    // Sprite-sheet tile
    return _SpriteTile(
      image: result.image,
      sourceRect: result.sourceRect!,
      width: _w,
      height: _h,
    );
  }

  // ── Timecode section ──────────────────────────────────────────────────────

  Widget _buildTimecodeSection() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: PrysmDS.sp8,
        vertical: config.hasImages ? PrysmDS.sp6 : PrysmDS.sp8,
      ),
      child: Text(
        _formatTimestamp(data.timestamp),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xE0FFFFFF),
          fontSize: isTv ? PrysmDS.textMd : PrysmDS.textSm,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  static String _formatTimestamp(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).abs();
    final s = d.inSeconds.remainder(60).abs();
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}'
          ':${m.toString().padLeft(2, '0')}'
          ':${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sprite tile renderer
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a sub-rectangle of a sprite-sheet image, scaled to fill [width]×[height].
///
/// [sourceRect] is normalised (0–1) — e.g. `Rect.fromLTWH(0.2, 0.0, 0.1, 0.167)`
/// for column 2, row 0 of a 10×6 sprite.
///
/// **Algorithm:**
/// The sprite is rendered at scale `(width/sw) × (height/sh)` so that one
/// tile exactly fills the preview box. A [FractionalTranslation] moves the
/// blown-up sprite so the desired tile is visible, and [ClipRect] crops the rest.
class _SpriteTile extends StatelessWidget {
  const _SpriteTile({
    required this.image,
    required this.sourceRect,
    required this.width,
    required this.height,
  });

  final ImageProvider image;
  final Rect sourceRect;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final sw = sourceRect.width.clamp(1e-4, 1.0);
    final sh = sourceRect.height.clamp(1e-4, 1.0);
    final fullW = width / sw;
    final fullH = height / sh;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: fullW,
          maxHeight: fullH,
          child: FractionalTranslation(
            // Shift by (−col/columns, −row/rows) expressed as fractions of
            // the scaled image dimensions. Because the child is fullW×fullH,
            // FractionalTranslation(-sourceRect.left, -sourceRect.top) shifts
            // by (-col*tileW, -row*tileH) — exactly what we need.
            translation: Offset(-sourceRect.left, -sourceRect.top),
            child: Image(
              image: image,
              width: fullW,
              height: fullH,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF1C1C1C)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1C1C1C),
      child: Center(
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: Color(0x66FFFFFF),
            strokeCap: StrokeCap.round,
          ),
        ),
      ),
    );
  }
}

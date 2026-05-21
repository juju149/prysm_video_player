import 'dart:collection';

import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result
// ─────────────────────────────────────────────────────────────────────────────

/// The resolved result for a single thumbnail position.
class PrysmThumbnailResult {
  const PrysmThumbnailResult({required this.image, this.sourceRect});

  /// The image to display. For sprite-sheet strategies this is the full sprite.
  final ImageProvider image;

  /// Sub-rectangle of [image] to display, in **normalised** coordinates (0–1).
  ///
  /// When null, the whole image is used (typical for per-frame image lists).
  /// When non-null, only this rect is cropped and scaled to fill the preview.
  final Rect? sourceRect;
}

// ─────────────────────────────────────────────────────────────────────────────
// Thumbnail entry (used by PrysmListThumbnailProvider)
// ─────────────────────────────────────────────────────────────────────────────

/// A single thumbnail entry, pairing a video timestamp with an image.
class PrysmThumbnailEntry {
  const PrysmThumbnailEntry({
    required this.timestamp,
    required this.image,
  });

  final Duration timestamp;
  final ImageProvider image;
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract provider
// ─────────────────────────────────────────────────────────────────────────────

/// Base class for all seek-preview thumbnail providers.
///
/// Implement [resolve] to return the best thumbnail for a given [position].
///
/// **Strategies shipped:**
/// - [PrysmListThumbnailProvider] — list of pre-generated images.
/// - [PrysmSpriteThumbnailProvider] — sprite-sheet grid image.
///
/// **Custom strategy:** extend this class and override [resolve].
///
/// **Fallback:** if your provider returns `null`, the player renders a
/// timecode-only bubble automatically.
abstract class PrysmThumbnailProvider {
  const PrysmThumbnailProvider();

  /// Resolve the best available thumbnail for [position].
  ///
  /// - [position] — requested video position.
  /// - [duration] — total video duration; may be [Duration.zero] for live.
  ///
  /// Return `null` if no thumbnail is available (triggers the timecode fallback).
  Future<PrysmThumbnailResult?> resolve(Duration position, Duration duration);

  /// Called when the video source changes or the player is disposed.
  ///
  /// Override to release any held resources (image caches, HTTP connections,
  /// isolates, etc.).
  void dispose() {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Strategy 1 – List of individual images
// ─────────────────────────────────────────────────────────────────────────────

/// Provides thumbnails from a sorted list of [PrysmThumbnailEntry] items.
///
/// The entry whose timestamp is closest at or before [position] is selected
/// (floor-seek). Entries are sorted by timestamp at construction.
///
/// ```dart
/// PrysmListThumbnailProvider([
///   PrysmThumbnailEntry(
///     timestamp: Duration.zero,
///     image: const NetworkImage('https://example.com/thumb_00.jpg'),
///   ),
///   PrysmThumbnailEntry(
///     timestamp: const Duration(seconds: 10),
///     image: const NetworkImage('https://example.com/thumb_10.jpg'),
///   ),
/// ])
/// ```
class PrysmListThumbnailProvider extends PrysmThumbnailProvider {
  PrysmListThumbnailProvider(List<PrysmThumbnailEntry> entries)
    : _entries = List<PrysmThumbnailEntry>.from(entries)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final List<PrysmThumbnailEntry> _entries;

  @override
  Future<PrysmThumbnailResult?> resolve(
    Duration position,
    Duration duration,
  ) async {
    if (_entries.isEmpty) return null;
    final entry = _floorEntry(position);
    return PrysmThumbnailResult(image: entry.image);
  }

  PrysmThumbnailEntry _floorEntry(Duration position) {
    int lo = 0, hi = _entries.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_entries[mid].timestamp <= position) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return _entries[lo];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Strategy 2 – Sprite-sheet grid
// ─────────────────────────────────────────────────────────────────────────────

/// Provides thumbnails from a sprite-sheet image arranged as a grid.
///
/// The grid contains [columns] × [rows] thumbnail tiles. Each tile represents
/// [interval] of video time starting at [startOffset].
///
/// This is the most bandwidth-efficient strategy for streaming apps: one image
/// request loads all seek thumbnails.
///
/// ```dart
/// PrysmSpriteThumbnailProvider(
///   sprite: const NetworkImage('https://cdn.example.com/sprites.jpg'),
///   interval: const Duration(seconds: 10),
///   columns: 10,
///   rows:    6,
/// )
/// ```
///
/// **Generating sprites:**
/// Use ffmpeg:
/// ```
/// ffmpeg -i video.mp4 -vf "fps=0.1,scale=160:90,tile=10x6" sprites.jpg
/// ```
class PrysmSpriteThumbnailProvider extends PrysmThumbnailProvider {
  const PrysmSpriteThumbnailProvider({
    required this.sprite,
    required this.interval,
    required this.columns,
    required this.rows,
    this.startOffset = Duration.zero,
  }) : assert(columns > 0, 'columns must be > 0'),
       assert(rows > 0, 'rows must be > 0');

  /// The sprite-sheet image.
  final ImageProvider sprite;

  /// Duration covered by each tile.
  final Duration interval;

  /// Number of tile columns in the sprite.
  final int columns;

  /// Number of tile rows in the sprite.
  final int rows;

  /// Position in the video where the first tile begins.
  final Duration startOffset;

  int get _tileCount => columns * rows;

  @override
  Future<PrysmThumbnailResult?> resolve(
    Duration position,
    Duration duration,
  ) async {
    final adjusted = position < startOffset ? Duration.zero : position - startOffset;
    final index = (adjusted.inMilliseconds / interval.inMilliseconds)
        .floor()
        .clamp(0, _tileCount - 1);
    final col = index % columns;
    final row = index ~/ columns;
    // Normalised source rect (0..1)
    final srcRect = Rect.fromLTWH(
      col / columns,
      row / rows,
      1 / columns,
      1 / rows,
    );
    return PrysmThumbnailResult(image: sprite, sourceRect: srcRect);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thumbnail configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Configures the seek-preview thumbnail overlay in [PrysmVideoPlayer].
///
/// Pass this to [PrysmVideoPlayer.thumbnails]. When no [provider] is set (or
/// `null` is passed to the constructor), a timecode-only bubble is displayed.
///
/// ```dart
/// PrysmVideoPlayer(
///   controller: controller,
///   thumbnails: PrysmThumbnailConfig(
///     provider: PrysmSpriteThumbnailProvider(
///       sprite: const NetworkImage('https://cdn.example.com/sprites.jpg'),
///       interval: const Duration(seconds: 10),
///       columns: 10,
///       rows: 6,
///     ),
///   ),
/// )
/// ```
class PrysmThumbnailConfig {
  const PrysmThumbnailConfig({
    required this.provider,
    this.previewWidth = 160.0,
    this.previewHeight = 90.0,
    this.tvPreviewWidth = 240.0,
    this.tvPreviewHeight = 135.0,
    this.throttle = const Duration(milliseconds: 80),
  });

  /// Timecode-only mode — shows a timecode bubble without any image.
  ///
  /// Useful to test the UI or when thumbnail images are not yet available.
  const PrysmThumbnailConfig.timecodeOnly()
    : provider = null,
      previewWidth = 0,
      previewHeight = 0,
      tvPreviewWidth = 0,
      tvPreviewHeight = 0,
      throttle = const Duration(milliseconds: 80);

  /// Thumbnail provider (null = timecode-only mode).
  final PrysmThumbnailProvider? provider;

  /// Preview image width for mobile and desktop. Should match tile aspect ratio.
  final double previewWidth;

  /// Preview image height for mobile and desktop.
  final double previewHeight;

  /// Preview image width for TV layouts.
  final double tvPreviewWidth;

  /// Preview image height for TV layouts.
  final double tvPreviewHeight;

  /// Minimum interval between thumbnail resolutions during drag/hover.
  ///
  /// The timecode label always updates immediately; only image loading is
  /// throttled to avoid unnecessary network/decoding pressure.
  final Duration throttle;

  bool get hasImages => provider != null && previewWidth > 0 && previewHeight > 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Memory cache (internal)
// ─────────────────────────────────────────────────────────────────────────────

/// LRU in-memory cache for resolved thumbnails.
///
/// Keys are quantised timestamps (in milliseconds) to allow neighbouring
/// positions to share cached results.
class PrysmThumbnailCache {
  PrysmThumbnailCache({this.maxSize = 24});

  final int maxSize;
  final LinkedHashMap<int, PrysmThumbnailResult> _map = LinkedHashMap();

  PrysmThumbnailResult? get(int key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value; // promote to MRU end
    return value;
  }

  void put(int key, PrysmThumbnailResult value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > maxSize) {
      _map.remove(_map.keys.first); // evict LRU
    }
  }

  void clear() => _map.clear();
}

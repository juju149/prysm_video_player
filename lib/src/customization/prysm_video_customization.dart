import 'package:flutter/material.dart';

import '../controller/prysm_video_controller.dart';
import '../core/prysm_video_config.dart';
import '../core/prysm_video_state.dart';
import '../errors/prysm_video_error.dart';
import '../subtitles/prysm_subtitles.dart';
import '../theme/prysm_ds.dart' show PrysmPlayerPlatform;
import '../theme/prysm_video_theme.dart';
import '../thumbnails/prysm_thumbnail_provider.dart';
import '../tracks/prysm_tracks.dart';

enum PrysmTrackPickerKind { speed, quality, subtitles, audio }

class PrysmPlayerBuildContext {
  const PrysmPlayerBuildContext({
    required this.controller,
    required this.state,
    required this.config,
    required this.theme,
    required this.platform,
    required this.visible,
    required this.onInteraction,
    required this.onFullscreen,
    required this.thumbnails,
  });

  final PrysmVideoController controller;
  final PrysmVideoState state;
  final PrysmVideoConfig config;
  final PrysmVideoTheme theme;
  final PrysmPlayerPlatform platform;
  final bool visible;
  final VoidCallback onInteraction;
  final Future<void> Function()? onFullscreen;
  final PrysmThumbnailConfig? thumbnails;
}

class PrysmProgressBarDetails {
  const PrysmProgressBarDetails({
    required this.context,
    required this.isTv,
    required this.child,
  });

  final PrysmPlayerBuildContext context;
  final bool isTv;
  final Widget child;
}

class PrysmPlayerSectionDetails {
  const PrysmPlayerSectionDetails({required this.context, required this.child});

  final PrysmPlayerBuildContext context;
  final Widget child;
}

class PrysmSettingsMenuDetails {
  const PrysmSettingsMenuDetails({required this.context, required this.child});

  final PrysmPlayerBuildContext context;
  final Widget child;
}

class PrysmTrackPickerDetails<T> {
  const PrysmTrackPickerDetails({
    required this.context,
    required this.kind,
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    required this.child,
  });

  final PrysmPlayerBuildContext context;
  final PrysmTrackPickerKind kind;
  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final Future<void> Function(T value) onSelected;
  final Widget child;
}

class PrysmSubtitleRendererDetails {
  const PrysmSubtitleRendererDetails({
    required this.context,
    required this.position,
    required this.selectedTrack,
    required this.subtitleStyle,
  });

  final PrysmPlayerBuildContext context;
  final Duration position;
  final PrysmSubtitleTrackInfo selectedTrack;
  final PrysmSubtitleStyle subtitleStyle;
}

class PrysmOverlayDetails {
  const PrysmOverlayDetails({required this.context, required this.child});

  final PrysmPlayerBuildContext context;
  final Widget child;
}

class PrysmLoadingDetails {
  const PrysmLoadingDetails({required this.context, required this.child});

  final PrysmPlayerBuildContext context;
  final Widget child;
}

class PrysmErrorDetails {
  const PrysmErrorDetails({
    required this.context,
    required this.error,
    required this.retry,
    required this.child,
  });

  final PrysmPlayerBuildContext context;
  final PrysmVideoError? error;
  final VoidCallback? retry;
  final Widget child;
}

class PrysmGestureDetails {
  const PrysmGestureDetails({required this.context, required this.child});

  final PrysmPlayerBuildContext context;
  final Widget child;
}

class PrysmKeyboardShortcutDetails {
  const PrysmKeyboardShortcutDetails({
    required this.context,
    required this.event,
    required this.defaultResult,
  });

  final PrysmPlayerBuildContext context;
  final KeyEvent event;
  final KeyEventResult defaultResult;
}

class PrysmTvFocusDetails {
  const PrysmTvFocusDetails({
    required this.context,
    required this.child,
    required this.focusNode,
    required this.focused,
  });

  final PrysmPlayerBuildContext context;
  final Widget child;
  final FocusNode focusNode;
  final bool focused;
}

typedef PrysmPlayerSectionBuilder =
    Widget Function(BuildContext context, PrysmPlayerSectionDetails details);

typedef PrysmPlayerOverlayBuilder =
    Widget Function(BuildContext context, PrysmOverlayDetails details);

typedef PrysmLoadingBuilder =
    Widget Function(BuildContext context, PrysmLoadingDetails details);

typedef PrysmErrorBuilder =
    Widget Function(BuildContext context, PrysmErrorDetails details);

typedef PrysmProgressBarBuilder =
    Widget Function(BuildContext context, PrysmProgressBarDetails details);

typedef PrysmSettingsMenuBuilder =
    Widget Function(BuildContext context, PrysmSettingsMenuDetails details);

typedef PrysmTrackPickerBuilder<T> =
    Widget Function(BuildContext context, PrysmTrackPickerDetails<T> details);

typedef PrysmSubtitleRendererBuilder =
    Widget Function(BuildContext context, PrysmSubtitleRendererDetails details);

typedef PrysmGestureBuilder =
    Widget Function(BuildContext context, PrysmGestureDetails details);

typedef PrysmKeyboardShortcutHandler =
    KeyEventResult Function(
      BuildContext context,
      PrysmKeyboardShortcutDetails details,
    );

typedef PrysmTvFocusBuilder =
    Widget Function(BuildContext context, PrysmTvFocusDetails details);

class PrysmVideoCustomization {
  const PrysmVideoCustomization({
    this.controlsBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.progressBarBuilder,
    this.settingsMenuBuilder,
    this.speedPickerBuilder,
    this.qualityPickerBuilder,
    this.subtitlePickerBuilder,
    this.audioPickerBuilder,
    this.subtitleRendererBuilder,
    this.topBarBuilder,
    this.bottomBarBuilder,
    this.gestureBuilder,
    this.keyboardShortcutHandler,
    this.tvFocusBuilder,
  });

  final PrysmPlayerOverlayBuilder? controlsBuilder;
  final PrysmLoadingBuilder? loadingBuilder;
  final PrysmErrorBuilder? errorBuilder;
  final PrysmProgressBarBuilder? progressBarBuilder;
  final PrysmSettingsMenuBuilder? settingsMenuBuilder;
  final PrysmTrackPickerBuilder<double>? speedPickerBuilder;
  final PrysmTrackPickerBuilder<PrysmVideoQuality>? qualityPickerBuilder;
  final PrysmTrackPickerBuilder<PrysmSubtitleTrackInfo>? subtitlePickerBuilder;
  final PrysmTrackPickerBuilder<PrysmAudioTrack>? audioPickerBuilder;
  final PrysmSubtitleRendererBuilder? subtitleRendererBuilder;
  final PrysmPlayerSectionBuilder? topBarBuilder;
  final PrysmPlayerSectionBuilder? bottomBarBuilder;
  final PrysmGestureBuilder? gestureBuilder;
  final PrysmKeyboardShortcutHandler? keyboardShortcutHandler;
  final PrysmTvFocusBuilder? tvFocusBuilder;
}

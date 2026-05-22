part of '../widgets/prysm_video_player.dart';

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
          style:
              style ??
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
    required this.customization,
    required this.details,
  });

  final PrysmVideoController controller;
  final PrysmVideoTheme theme;
  final VoidCallback onInteraction;
  final PrysmVideoCustomization customization;
  final PrysmPlayerBuildContext details;

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
      builder: (ctx) {
        final defaultSheet = _SettingsSheet(
          controller: controller,
          theme: theme,
          customization: customization,
          details: details,
        );
        final builder = customization.settingsMenuBuilder;
        if (builder == null) return defaultSheet;
        return builder(
          ctx,
          PrysmSettingsMenuDetails(context: details, child: defaultSheet),
        );
      },
    );
  }
}

// Settings main sheet
class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
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
      customization: customization,
      details: details,
      kind: PrysmTrackPickerKind.speed,
      builder: customization.speedPickerBuilder,
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
      customization: customization,
      details: details,
      kind: PrysmTrackPickerKind.quality,
      builder: customization.qualityPickerBuilder,
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
      customization: customization,
      details: details,
      kind: PrysmTrackPickerKind.subtitles,
      builder: customization.subtitlePickerBuilder,
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
      customization: customization,
      details: details,
      kind: PrysmTrackPickerKind.audio,
      builder: customization.audioPickerBuilder,
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

Future<void> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T) label,
  required T selected,
  required Future<void> Function(T) onSelected,
  required PrysmVideoCustomization customization,
  required PrysmPlayerBuildContext details,
  required PrysmTrackPickerKind kind,
  required PrysmTrackPickerBuilder<T>? builder,
}) {
  Widget defaultSheet(BuildContext ctx) => DraggableScrollableSheet(
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
                bottom: MediaQuery.paddingOf(context).bottom + PrysmDS.sp8,
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
  );

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black38,
    isScrollControlled: true,
    builder: (ctx) {
      final child = defaultSheet(ctx);
      if (builder == null) return child;
      return builder(
        ctx,
        PrysmTrackPickerDetails<T>(
          context: details,
          kind: kind,
          title: title,
          values: values,
          selected: selected,
          label: label,
          onSelected: onSelected,
          child: child,
        ),
      );
    },
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

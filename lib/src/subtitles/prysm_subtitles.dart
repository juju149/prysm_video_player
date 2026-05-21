import 'package:flutter/material.dart';

enum PrysmSubtitleFormat { webVtt, srt, unknown }

class PrysmSubtitleSource {
  const PrysmSubtitleSource._({
    required this.uri,
    required this.format,
    required this.inlineData,
    this.headers = const <String, String>{},
  });

  factory PrysmSubtitleSource.network(
    String url, {
    PrysmSubtitleFormat? format,
    Map<String, String> headers = const <String, String>{},
  }) {
    return PrysmSubtitleSource._(
      uri: url,
      format: format ?? _inferSubtitleFormat(url),
      inlineData: false,
      headers: headers,
    );
  }

  factory PrysmSubtitleSource.asset(
    String assetPath, {
    PrysmSubtitleFormat? format,
  }) {
    return PrysmSubtitleSource._(
      uri: assetPath.startsWith('asset:///')
          ? assetPath
          : 'asset:///$assetPath',
      format: format ?? _inferSubtitleFormat(assetPath),
      inlineData: false,
    );
  }

  factory PrysmSubtitleSource.data(
    String data, {
    PrysmSubtitleFormat format = PrysmSubtitleFormat.webVtt,
  }) {
    return PrysmSubtitleSource._(uri: data, format: format, inlineData: true);
  }

  final String uri;
  final PrysmSubtitleFormat format;
  final bool inlineData;
  final Map<String, String> headers;
}

class PrysmSubtitleTrack {
  const PrysmSubtitleTrack({
    required this.id,
    required this.label,
    required this.languageCode,
    required this.source,
    this.defaultTrack = false,
  });

  final String id;
  final String label;
  final String languageCode;
  final PrysmSubtitleSource source;
  final bool defaultTrack;
}

class PrysmSubtitleStyle {
  const PrysmSubtitleStyle({
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      shadows: <Shadow>[Shadow(blurRadius: 3)],
    ),
    this.backgroundColor = const Color(0x99000000),
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius = 4,
    this.bottomOffset = 72,
  });

  final TextStyle textStyle;
  final Color backgroundColor;
  final EdgeInsets padding;
  final double borderRadius;
  final double bottomOffset;
}

class PrysmSubtitleCue {
  const PrysmSubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

class PrysmSubtitleParser {
  const PrysmSubtitleParser();

  List<PrysmSubtitleCue> parse(String content, PrysmSubtitleFormat format) {
    return switch (format) {
      PrysmSubtitleFormat.srt => parseSrt(content),
      PrysmSubtitleFormat.webVtt => parseWebVtt(content),
      PrysmSubtitleFormat.unknown => parseWebVtt(content),
    };
  }

  List<PrysmSubtitleCue> parseSrt(String content) {
    final blocks = content.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
    final cues = <PrysmSubtitleCue>[];
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((line) => line.trimRight())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;
      final timingIndex = lines.indexWhere((line) => line.contains('-->'));
      if (timingIndex < 0) continue;
      final timing = lines[timingIndex].split('-->');
      if (timing.length != 2) continue;
      final start = _parseSubtitleDuration(timing[0]);
      final end = _parseSubtitleDuration(timing[1]);
      if (start == null || end == null || end <= start) continue;
      cues.add(
        PrysmSubtitleCue(
          start: start,
          end: end,
          text: lines.skip(timingIndex + 1).join('\n').trim(),
        ),
      );
    }
    return cues;
  }

  List<PrysmSubtitleCue> parseWebVtt(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trimLeft();
    final withoutHeader = normalized.replaceFirst(
      RegExp(r'^\uFEFF?WEBVTT[^\n]*\n'),
      '',
    );
    final blocks = withoutHeader.split(RegExp(r'\n\s*\n'));
    final cues = <PrysmSubtitleCue>[];
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((line) => line.trimRight())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;
      final timingIndex = lines.indexWhere((line) => line.contains('-->'));
      if (timingIndex < 0) continue;
      final timing = lines[timingIndex].split('-->');
      if (timing.length != 2) continue;
      final start = _parseSubtitleDuration(timing[0]);
      final end = _parseSubtitleDuration(
        timing[1].trim().split(RegExp(r'\s+')).first,
      );
      if (start == null || end == null || end <= start) continue;
      cues.add(
        PrysmSubtitleCue(
          start: start,
          end: end,
          text: lines.skip(timingIndex + 1).join('\n').trim(),
        ),
      );
    }
    return cues;
  }
}

PrysmSubtitleFormat _inferSubtitleFormat(String uri) {
  final lower = uri.toLowerCase();
  if (lower.endsWith('.srt')) return PrysmSubtitleFormat.srt;
  if (lower.endsWith('.vtt') || lower.endsWith('.webvtt')) {
    return PrysmSubtitleFormat.webVtt;
  }
  return PrysmSubtitleFormat.unknown;
}

Duration? _parseSubtitleDuration(String raw) {
  final value = raw.trim().replaceAll(',', '.');
  final parts = value.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final secondsParts = parts.last.split('.');
  final seconds = int.tryParse(secondsParts.first);
  if (seconds == null) return null;
  final milliseconds = secondsParts.length > 1
      ? int.tryParse(secondsParts[1].padRight(3, '0').substring(0, 3)) ?? 0
      : 0;
  final minutes = int.tryParse(parts[parts.length - 2]);
  if (minutes == null) return null;
  final hours = parts.length == 3 ? int.tryParse(parts.first) : 0;
  if (hours == null) return null;
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
  );
}

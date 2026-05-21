import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import '../data_source/prysm_video_source.dart';
import '../subtitles/prysm_subtitles.dart';
import '../tracks/prysm_tracks.dart';
import 'prysm_playback_backend.dart';

class PrysmVideoKit {
  const PrysmVideoKit._();

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    mk.MediaKit.ensureInitialized();
    _initialized = true;
  }
}

class MediaKitPlaybackBackend implements PrysmPlaybackBackend {
  MediaKitPlaybackBackend({mk.Player? player})
    : player = player ?? _createPlayer(),
      _ownsPlayer = player == null {
    videoController = VideoController(this.player);
  }

  final mk.Player player;
  final bool _ownsPlayer;

  @override
  late final VideoController videoController;

  @override
  Stream<bool> get playing => player.stream.playing;

  @override
  Stream<bool> get completed => player.stream.completed;

  @override
  Stream<bool> get buffering => player.stream.buffering;

  @override
  Stream<Duration> get position => player.stream.position;

  @override
  Stream<Duration> get duration => player.stream.duration;

  @override
  Stream<Duration> get buffer => player.stream.buffer;

  @override
  Stream<double> get volume => player.stream.volume;

  @override
  Stream<double> get speed => player.stream.rate;

  @override
  Stream<Object> get errors => player.stream.error;

  @override
  late final Stream<PrysmAvailableTracks> availableTracks =
      player.stream.tracks.map(_mapAvailableTracks);

  @override
  late final Stream<PrysmSelectedTracks> selectedTracks =
      player.stream.track.map(_mapSelectedTracks);

  @override
  PrysmAvailableTracks get currentAvailableTracks {
    return _mapAvailableTracks(player.state.tracks);
  }

  @override
  PrysmSelectedTracks get currentSelectedTracks {
    return _mapSelectedTracks(player.state.track);
  }

  @override
  Future<void> open(
    PrysmVideoSource source, {
    PrysmVideoQuality? quality,
    bool play = true,
  }) async {
    if (source.isPlaylist) {
      final media = await Future.wait(
        source.items.map((item) => item.toMedia()),
      );
      await player.open(mk.Playlist(media), play: play);
    } else {
      await player.open(await source.toMedia(quality: quality), play: play);
    }

    for (final subtitle in source.externalSubtitles) {
      if (subtitle.defaultTrack) {
        await _selectExternalSubtitle(subtitle);
        break;
      }
    }
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> playOrPause() => player.playOrPause();

  @override
  Future<void> stop() => player.stop();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> setVolume(double volume) =>
      player.setVolume(volume.clamp(0, 100));

  @override
  Future<void> setSpeed(double speed) => player.setRate(speed.clamp(0.25, 3.0));

  @override
  Future<void> setLooping(bool enabled) {
    return player.setPlaylistMode(
      enabled ? mk.PlaylistMode.loop : mk.PlaylistMode.none,
    );
  }

  @override
  Future<void> selectVideoTrack(String id) {
    final track = player.state.tracks.video.firstWhere(
      (item) => item.id == id,
      orElse: () => id == 'no' ? mk.VideoTrack.no() : mk.VideoTrack.auto(),
    );
    return player.setVideoTrack(track);
  }

  @override
  Future<void> selectAudioTrack(String id) {
    final track = player.state.tracks.audio.firstWhere(
      (item) => item.id == id,
      orElse: () => id == 'no' ? mk.AudioTrack.no() : mk.AudioTrack.auto(),
    );
    return player.setAudioTrack(track);
  }

  @override
  Future<void> selectSubtitleTrack(String id) {
    final track = player.state.tracks.subtitle.firstWhere(
      (item) => item.id == id,
      orElse: () =>
          id == 'no' ? mk.SubtitleTrack.no() : mk.SubtitleTrack.auto(),
    );
    return player.setSubtitleTrack(track);
  }

  @override
  Future<void> dispose() async {
    if (_ownsPlayer) {
      await player.dispose();
    }
  }

  Future<void> _selectExternalSubtitle(PrysmSubtitleTrack track) {
    final source = track.source;
    final subtitle = source.inlineData
        ? mk.SubtitleTrack.data(
            source.uri,
            title: track.label,
            language: track.languageCode,
          )
        : mk.SubtitleTrack.uri(
            source.uri,
            title: track.label,
            language: track.languageCode,
          );
    return player.setSubtitleTrack(subtitle);
  }
}

mk.Player _createPlayer() {
  PrysmVideoKit.ensureInitialized();
  return mk.Player();
}

PrysmAvailableTracks _mapAvailableTracks(mk.Tracks tracks) {
  return PrysmAvailableTracks(
    video: tracks.video.map(_mapVideoTrack).toList(growable: false),
    audio: tracks.audio.map(_mapAudioTrack).toList(growable: false),
    subtitles: tracks.subtitle.map(_mapSubtitleTrack).toList(growable: false),
  );
}

PrysmSelectedTracks _mapSelectedTracks(mk.Track track) {
  return PrysmSelectedTracks(
    video: _mapVideoTrack(track.video),
    audio: _mapAudioTrack(track.audio),
    subtitle: _mapSubtitleTrack(track.subtitle),
  );
}

PrysmVideoTrack _mapVideoTrack(mk.VideoTrack track) {
  return PrysmVideoTrack(
    id: track.id,
    label: _trackLabel(track.id, track.title, track.language, track.h),
    width: track.w,
    height: track.h,
    codec: track.codec,
    bitrate: track.bitrate,
  );
}

PrysmAudioTrack _mapAudioTrack(mk.AudioTrack track) {
  return PrysmAudioTrack(
    id: track.id,
    label: _trackLabel(track.id, track.title, track.language, null),
    languageCode: track.language,
    codec: track.codec,
    bitrate: track.bitrate,
    defaultTrack: track.isDefault ?? false,
    audioDescription: (track.title ?? '').toLowerCase().contains('description'),
  );
}

PrysmSubtitleTrackInfo _mapSubtitleTrack(mk.SubtitleTrack track) {
  return PrysmSubtitleTrackInfo(
    id: track.id,
    label: _trackLabel(track.id, track.title, track.language, null),
    languageCode: track.language,
    codec: track.codec,
    external: track.uri || track.data,
  );
}

String _trackLabel(String id, String? title, String? language, int? height) {
  if (id == 'auto') return 'Auto';
  if (id == 'no') return 'Off';
  if (title != null && title.isNotEmpty) return title;
  if (height != null && height > 0) return '${height}p';
  if (language != null && language.isNotEmpty) return language.toUpperCase();
  return id;
}

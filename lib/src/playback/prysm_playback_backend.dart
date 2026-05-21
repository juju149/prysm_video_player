import 'package:media_kit_video/media_kit_video.dart';

import '../data_source/prysm_video_source.dart';
import '../tracks/prysm_tracks.dart';

abstract interface class PrysmPlaybackBackend {
  VideoController get videoController;

  Stream<bool> get playing;
  Stream<bool> get completed;
  Stream<bool> get buffering;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<Duration> get buffer;
  Stream<double> get volume;
  Stream<double> get speed;
  Stream<Object> get errors;
  Stream<PrysmAvailableTracks> get availableTracks;
  Stream<PrysmSelectedTracks> get selectedTracks;

  PrysmAvailableTracks get currentAvailableTracks;
  PrysmSelectedTracks get currentSelectedTracks;

  Future<void> open(
    PrysmVideoSource source, {
    PrysmVideoQuality? quality,
    bool play = true,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);
  Future<void> setLooping(bool enabled);
  Future<void> selectVideoTrack(String id);
  Future<void> selectAudioTrack(String id);
  Future<void> selectSubtitleTrack(String id);
  Future<void> dispose();
}

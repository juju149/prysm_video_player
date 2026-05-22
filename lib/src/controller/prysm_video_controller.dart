import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../cache/prysm_video_cache.dart';
import '../casting/prysm_cast.dart';
import '../core/prysm_video_config.dart';
import '../core/prysm_video_event.dart';
import '../core/prysm_video_state.dart';
import '../data_source/prysm_video_source.dart';
import '../drm/prysm_drm_config.dart';
import '../errors/prysm_video_error.dart';
import '../media/prysm_media_integration.dart';
import '../pip/prysm_picture_in_picture.dart';
import '../playback/media_kit_playback_backend.dart';
import '../playback/prysm_playback_backend.dart';
import '../tracks/prysm_tracks.dart';

class PrysmVideoController extends ChangeNotifier {
  PrysmVideoController({
    PrysmVideoSource? source,
    this.config = const PrysmVideoConfig(),
    PrysmPlaybackBackend? backend,
    PrysmVideoCache? cache,
    PrysmDrmAdapter? drmAdapter,
    PrysmPictureInPictureAdapter? pictureInPicture,
    PrysmMediaIntegration? mediaIntegration,
    PrysmCastAdapter? castAdapter,
  }) : source = source,
       _backend = backend ?? MediaKitPlaybackBackend(),
       _cache = cache ?? createPrysmVideoCache(),
       _drmAdapter = drmAdapter ?? const PrysmNoopDrmAdapter(),
       _pictureInPicture =
           pictureInPicture ?? const PrysmNoopPictureInPictureAdapter(),
       _mediaIntegration =
           mediaIntegration ?? const PrysmNoopMediaIntegration(),
       _castAdapter = castAdapter ?? const PrysmNoopCastAdapter() {
    _state = PrysmVideoState(
      source: source,
      volume: config.muted ? 0 : config.initialVolume.clamp(0, 100),
      muted: config.muted,
      speed: config.initialSpeed.clamp(0.25, 3),
      looping: config.looping,
      selectedQuality: config.preferredQuality,
    );
    _lastAudibleVolume = _state.volume > 0 ? _state.volume : 100;
    _bind();
    _bindRemoteCommands();
    unawaited(_backend.setVolume(_state.volume));
    unawaited(_backend.setSpeed(_state.speed));
    unawaited(_backend.setLooping(config.looping));
    unawaited(
      _mediaIntegration.setBackgroundAudioEnabled(config.enableBackgroundAudio),
    );
    unawaited(
      _mediaIntegration.setNotificationsEnabled(
        config.enableMediaNotifications,
      ),
    );
    _emit(PrysmVideoEvent(type: PrysmVideoEventType.playerInitialized));
  }

  final PrysmVideoSource? source;
  final PrysmVideoConfig config;
  final PrysmPlaybackBackend _backend;
  final PrysmVideoCache _cache;
  final PrysmDrmAdapter _drmAdapter;
  final PrysmPictureInPictureAdapter _pictureInPicture;
  final PrysmMediaIntegration _mediaIntegration;
  final PrysmCastAdapter _castAdapter;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  final StreamController<PrysmVideoEvent> _events =
      StreamController<PrysmVideoEvent>.broadcast();
  final Stopwatch _startupWatch = Stopwatch();
  final Stopwatch _seekWatch = Stopwatch();

  late PrysmVideoState _state;
  late double _lastAudibleVolume;
  bool _disposed = false;
  DateTime _lastPositionUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  PrysmVideoState get state => _state;

  @Deprecated('Use state instead.')
  PrysmVideoState get snapshot => _state;

  Stream<PrysmVideoEvent> get events => _events.stream;

  VideoController get videoController => _backend.videoController;

  bool get isDisposed => _disposed;

  void _bind() {
    _subscriptions
      ..add(
        _backend.playing.listen((value) {
          _update(
            _state.copyWith(
              playing: value,
              status: value
                  ? PrysmPlaybackStatus.playing
                  : PrysmPlaybackStatus.paused,
            ),
          );
          _emit(
            PrysmVideoEvent(
              type: value
                  ? PrysmVideoEventType.playbackStarted
                  : PrysmVideoEventType.playbackPaused,
              position: _state.position,
            ),
          );
          unawaited(_syncMediaPlayback());
        }),
      )
      ..add(
        _backend.completed.listen((value) {
          if (!value) return;
          _update(
            _state.copyWith(
              completed: true,
              playing: false,
              status: PrysmPlaybackStatus.ended,
            ),
          );
          _emit(
            PrysmVideoEvent(
              type: PrysmVideoEventType.playbackCompleted,
              position: _state.position,
            ),
          );
        }),
      )
      ..add(
        _backend.buffering.listen((value) {
          final wasBuffering = _state.buffering;
          final metrics = value && !wasBuffering
              ? _state.metrics.copyWith(
                  rebufferCount: _state.metrics.rebufferCount + 1,
                )
              : _state.metrics;
          // Preserve ended status when buffering oscillates after completion.
          final newStatus = value
              ? PrysmPlaybackStatus.buffering
              : _state.completed
              ? PrysmPlaybackStatus.ended
              : _state.playing
              ? PrysmPlaybackStatus.playing
              : PrysmPlaybackStatus.ready;
          _update(
            _state.copyWith(
              buffering: value,
              status: newStatus,
              metrics: metrics,
            ),
          );
          if (value != wasBuffering) {
            _emit(
              PrysmVideoEvent(
                type: value
                    ? PrysmVideoEventType.bufferingStarted
                    : PrysmVideoEventType.bufferingEnded,
                position: _state.position,
              ),
            );
          }
        }),
      )
      ..add(
        _backend.position.listen((value) {
          final now = DateTime.now();
          if (now.difference(_lastPositionUpdate) < config.positionThrottle) {
            return;
          }
          final clamped = _clampPosition(value);
          if (clamped == _state.position) return;
          _lastPositionUpdate = now;
          _update(_state.copyWith(position: clamped));
          unawaited(_syncMediaPlayback());
          if (_startupWatch.isRunning && value > Duration.zero) {
            _startupWatch.stop();
            _update(
              _state.copyWith(
                metrics: _state.metrics.copyWith(
                  timeToFirstFrame: _startupWatch.elapsed,
                  startupLatency: _startupWatch.elapsed,
                ),
              ),
            );
          }
        }),
      )
      ..add(
        _backend.duration.listen((value) {
          if (value == _state.duration) return;
          _update(_state.copyWith(duration: value));
          unawaited(_syncMediaMetadata());
        }),
      )
      ..add(
        _backend.buffer.listen((value) {
          if (value == _state.bufferedPosition) return;
          final buffered = value > _state.position
              ? value - _state.position
              : Duration.zero;
          _update(
            _state.copyWith(
              bufferedPosition: value,
              metrics: _state.metrics.copyWith(bufferedDuration: buffered),
            ),
          );
        }),
      )
      ..add(
        _backend.volume.listen((value) {
          if (value == _state.volume) return;
          if (value > 0) _lastAudibleVolume = value;
          _update(_state.copyWith(volume: value, muted: value <= 0));
        }),
      )
      ..add(
        _backend.speed.listen((value) {
          if (value == _state.speed) return;
          _update(_state.copyWith(speed: value));
          unawaited(_syncMediaPlayback());
        }),
      )
      ..add(
        _backend.availableTracks.listen((value) {
          if (value == _state.availableTracks) return;
          _update(
            _state.copyWith(
              availableTracks: value,
              availableQualities: _qualitiesFromTracks(
                value.video,
                _state.source,
              ),
            ),
          );
        }),
      )
      ..add(
        _backend.selectedTracks.listen((value) {
          if (value == _state.selectedTracks) return;
          _update(_state.copyWith(selectedTracks: value));
        }),
      )
      ..add(
        _backend.errors.listen((value) {
          final error = PrysmVideoError.map(value);
          _update(
            _state.copyWith(status: PrysmPlaybackStatus.error, error: error),
          );
          _emit(PrysmVideoEvent(type: PrysmVideoEventType.error, error: error));
        }),
      );
  }

  void _bindRemoteCommands() {
    _subscriptions.add(
      _mediaIntegration.remoteCommands.listen((command) {
        _emit(
          PrysmVideoEvent(
            type: PrysmVideoEventType.remoteCommandReceived,
            position: _state.position,
            data: <String, Object?>{'command': command.type.name},
          ),
        );
        unawaited(_handleRemoteCommand(command));
      }),
    );
  }

  Future<void> _handleRemoteCommand(PrysmRemoteCommand command) {
    return switch (command.type) {
      PrysmRemoteCommandType.play => play(),
      PrysmRemoteCommandType.pause => pause(),
      PrysmRemoteCommandType.toggle => toggle(),
      PrysmRemoteCommandType.stop => stop(),
      PrysmRemoteCommandType.seekTo => seekTo(
        command.position ?? _state.position,
      ),
      PrysmRemoteCommandType.seekBy => seekBy(command.delta ?? Duration.zero),
      PrysmRemoteCommandType.forward => seekBy(config.seekStep),
      PrysmRemoteCommandType.replay => seekBy(-config.seekStep),
      PrysmRemoteCommandType.mute => mute(),
      PrysmRemoteCommandType.unmute => unmute(),
    };
  }

  Future<void> open(PrysmVideoSource source, {bool? play}) {
    return _guard(() async {
      _startupWatch
        ..reset()
        ..start();
      final selectedQuality = _selectInitialQuality(source);
      _update(
        _state.copyWith(
          source: source,
          live: source.isLive,
          completed: false,
          status: PrysmPlaybackStatus.opening,
          selectedQuality: selectedQuality,
          availableQualities: _qualitiesFromSource(source),
          // Reset playback position so the UI never briefly shows stale state
          // from the previous video while the new source is loading.
          position: Duration.zero,
          duration: Duration.zero,
          bufferedPosition: Duration.zero,
          clearError: true,
        ),
      );

      var resolvedSource = source;
      final drm = source.drm;
      if (drm != null) {
        final drmExtras = await _drmAdapter.prepare(drm);
        resolvedSource = resolvedSource.copyWith(
          extras: <String, Object?>{...resolvedSource.extras, 'drm': drmExtras},
        );
        _emit(
          PrysmVideoEvent(
            type: PrysmVideoEventType.drmPrepared,
            position: _state.position,
            data: <String, Object?>{'scheme': drm.scheme.name},
          ),
        );
      }

      final cacheResult = await _cache.resolve(resolvedSource, config.cache);
      resolvedSource = cacheResult.source;
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.cacheResolved,
          position: _state.position,
          data: <String, Object?>{
            'reason': cacheResult.reason.name,
            if (cacheResult.cacheKey != null) 'cacheKey': cacheResult.cacheKey,
            if (cacheResult.path != null) 'path': cacheResult.path,
            if (cacheResult.bytes != null) 'bytes': cacheResult.bytes,
          },
        ),
      );

      await _backend.open(
        resolvedSource,
        quality: selectedQuality,
        play: play ?? config.autoPlay,
      );
      if (config.startAt > Duration.zero) {
        await seekTo(config.startAt);
      }
      _update(_state.copyWith(status: PrysmPlaybackStatus.ready));
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.sourceOpened,
          position: _state.position,
        ),
      );
      await _syncMediaMetadata();
      await _syncMediaPlayback();
    });
  }

  Future<void> preload([PrysmVideoSource? preloadSource]) {
    return open(preloadSource ?? _requireSource(), play: false);
  }

  Future<void> play() => _guard(_backend.play);

  Future<void> pause() => _guard(_backend.pause);

  Future<void> toggle() => _guard(_backend.playOrPause);

  Future<void> stop() => _guard(_backend.stop);

  Future<void> seekTo(Duration position) {
    return _guard(() async {
      _seekWatch
        ..reset()
        ..start();
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.seekStarted,
          position: _state.position,
        ),
      );
      final clamped = _clampPosition(position);
      _update(_state.copyWith(position: clamped));
      await _backend.seek(clamped);
      _seekWatch.stop();
      _update(
        _state.copyWith(
          metrics: _state.metrics.copyWith(seekLatency: _seekWatch.elapsed),
        ),
      );
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.seekCompleted,
          position: clamped,
        ),
      );
      if (_state.casting) {
        await _castAdapter.updatePosition(clamped);
      }
    });
  }

  Future<void> seekBy(Duration delta) => seekTo(_state.position + delta);

  Future<void> replay10() => seekBy(-config.seekStep);

  Future<void> forward10() => seekBy(config.seekStep);

  Future<void> setSpeed(double speed) => _guard(() => _backend.setSpeed(speed));

  Future<void> setVolume(double volume) {
    return _guard(() {
      final next = volume.clamp(0, 100).toDouble();
      if (next > 0) _lastAudibleVolume = next;
      return _backend.setVolume(next);
    });
  }

  Future<void> mute() {
    return _guard(() {
      if (_state.volume > 0) _lastAudibleVolume = _state.volume;
      return _backend.setVolume(0);
    });
  }

  Future<void> unmute() =>
      setVolume(_lastAudibleVolume <= 0 ? 100 : _lastAudibleVolume);

  Future<void> toggleMute() => _state.muted ? unmute() : mute();

  Future<void> setLooping(bool enabled) {
    return _guard(() async {
      await _backend.setLooping(enabled);
      _update(_state.copyWith(looping: enabled));
    });
  }

  Future<void> selectSubtitleTrack(String id) {
    return _guard(() async {
      await _backend.selectSubtitleTrack(id);
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.subtitleChanged,
          position: _state.position,
          data: <String, Object?>{'id': id},
        ),
      );
    });
  }

  Future<void> selectAudioTrack(String id) {
    return _guard(() async {
      await _backend.selectAudioTrack(id);
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.audioTrackChanged,
          position: _state.position,
          data: <String, Object?>{'id': id},
        ),
      );
    });
  }

  Future<void> selectVideoQuality(PrysmVideoQuality quality) {
    return _guard(() async {
      final source = _state.source ?? _requireSource();
      final currentPosition = _state.position;
      final wasPlaying = _state.playing;
      if (source.isMultiQuality && quality.url != null) {
        await _backend.open(source, quality: quality, play: wasPlaying);
        await _backend.seek(currentPosition);
      } else {
        await _backend.selectVideoTrack(quality.id);
      }
      _update(
        _state.copyWith(selectedQuality: quality, position: currentPosition),
      );
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.qualityChanged,
          position: currentPosition,
          data: <String, Object?>{'id': quality.id, 'label': quality.label},
        ),
      );
    });
  }

  Future<void> enterFullscreen() async {
    _ensureNotDisposed();
    _update(_state.copyWith(fullscreen: true));
    _emit(
      PrysmVideoEvent(
        type: PrysmVideoEventType.fullscreenEntered,
        position: _state.position,
      ),
    );
  }

  Future<void> exitFullscreen() async {
    _ensureNotDisposed();
    _update(_state.copyWith(fullscreen: false));
    _emit(
      PrysmVideoEvent(
        type: PrysmVideoEventType.fullscreenExited,
        position: _state.position,
      ),
    );
  }

  Future<void> enablePictureInPicture() async {
    return _guard(() async {
      final state = await _pictureInPicture.enter(_state);
      _update(_state.copyWith(pictureInPicture: state.enabled));
      _emit(
        PrysmVideoEvent(
          type: state.enabled
              ? PrysmVideoEventType.pipEntered
              : PrysmVideoEventType.pipExited,
          position: _state.position,
          data: <String, Object?>{'support': state.support.name},
        ),
      );
    });
  }

  Future<void> disablePictureInPicture() async {
    return _guard(() async {
      final state = await _pictureInPicture.exit();
      _update(_state.copyWith(pictureInPicture: state.enabled));
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.pipExited,
          position: _state.position,
          data: <String, Object?>{'support': state.support.name},
        ),
      );
    });
  }

  Future<List<PrysmCastDevice>> discoverCastDevices() {
    _ensureNotDisposed();
    return _castAdapter.discover();
  }

  Future<PrysmCastSession> startCasting(PrysmCastDevice device) {
    return _guardValue(() async {
      final source = _state.source ?? _requireSource();
      final session = await _castAdapter.start(
        device: device,
        source: source,
        position: _state.position,
      );
      _update(_state.copyWith(casting: session.active));
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.castingStarted,
          position: _state.position,
          data: <String, Object?>{
            'deviceId': device.id,
            'deviceName': device.name,
            'deviceType': device.type.name,
            'active': session.active,
          },
        ),
      );
      return session;
    });
  }

  Future<void> stopCasting() {
    return _guard(() async {
      await _castAdapter.stop();
      _update(_state.copyWith(casting: false));
      _emit(
        PrysmVideoEvent(
          type: PrysmVideoEventType.castingStopped,
          position: _state.position,
        ),
      );
    });
  }

  void setControlsLocked(bool locked) {
    _ensureNotDisposed();
    _update(_state.copyWith(controlsLocked: locked));
  }

  void _update(PrysmVideoState next) {
    if (_disposed) return;
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  void _emit(PrysmVideoEvent event) {
    if (_events.isClosed) return;
    _events.add(event);
  }

  Future<void> _syncMediaMetadata() async {
    await _mediaIntegration.setMetadata(PrysmMediaMetadata.fromState(_state));
    _emit(
      PrysmVideoEvent(
        type: PrysmVideoEventType.mediaSessionUpdated,
        position: _state.position,
        data: const <String, Object?>{'scope': 'metadata'},
      ),
    );
  }

  Future<void> _syncMediaPlayback() async {
    await _mediaIntegration.setPlayback(
      PrysmMediaPlaybackSnapshot.fromState(_state),
    );
    _emit(
      PrysmVideoEvent(
        type: PrysmVideoEventType.mediaSessionUpdated,
        position: _state.position,
        data: const <String, Object?>{'scope': 'playback'},
      ),
    );
  }

  Future<void> _guard(Future<void> Function() body) async {
    _ensureNotDisposed();
    try {
      await body();
    } catch (error) {
      final mapped = error is PrysmVideoError
          ? error
          : PrysmVideoError.map(error);
      _update(
        _state.copyWith(status: PrysmPlaybackStatus.error, error: mapped),
      );
      _emit(PrysmVideoEvent(type: PrysmVideoEventType.error, error: mapped));
      throw mapped;
    }
  }

  Future<T> _guardValue<T>(Future<T> Function() body) async {
    _ensureNotDisposed();
    try {
      return await body();
    } catch (error) {
      final mapped = error is PrysmVideoError
          ? error
          : PrysmVideoError.map(error);
      _update(
        _state.copyWith(status: PrysmPlaybackStatus.error, error: mapped),
      );
      _emit(PrysmVideoEvent(type: PrysmVideoEventType.error, error: mapped));
      throw mapped;
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) throw const PrysmDisposedVideoError();
  }

  PrysmVideoSource _requireSource() {
    final initial = source ?? _state.source;
    if (initial == null) {
      throw StateError('No PrysmVideoSource is attached to this controller.');
    }
    return initial;
  }

  Duration _clampPosition(Duration value) {
    if (value < Duration.zero) return Duration.zero;
    final duration = _state.duration;
    if (duration > Duration.zero && value > duration) return duration;
    return value;
  }

  PrysmVideoQuality _selectInitialQuality(PrysmVideoSource source) {
    if (config.preferredQuality.auto) return const PrysmVideoQuality.auto();
    final qualities = _qualitiesFromSource(source);
    return qualities.firstWhere(
      (quality) => quality.id == config.preferredQuality.id,
      orElse: () => config.preferredQuality,
    );
  }

  List<PrysmVideoQuality> _qualitiesFromSource(PrysmVideoSource source) {
    if (source.qualities.isNotEmpty) return source.qualities;
    return const <PrysmVideoQuality>[PrysmVideoQuality.auto()];
  }

  List<PrysmVideoQuality> _qualitiesFromTracks(
    List<PrysmVideoTrack> tracks,
    PrysmVideoSource? source,
  ) {
    if (source != null && source.qualities.isNotEmpty) return source.qualities;
    final qualities = <PrysmVideoQuality>[const PrysmVideoQuality.auto()];
    for (final track in tracks) {
      if (track.id == 'auto' || track.id == 'no') continue;
      qualities.add(
        PrysmVideoQuality(
          id: track.id,
          label: track.height == null ? track.label : '${track.height}p',
          width: track.width,
          height: track.height,
          bitrate: track.bitrate,
        ),
      );
    }
    return qualities;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _emit(
      PrysmVideoEvent(
        type: PrysmVideoEventType.disposed,
        position: _state.position,
      ),
    );
    unawaited(_events.close());
    unawaited(_mediaIntegration.dispose());
    unawaited(_backend.dispose());
    super.dispose();
  }
}

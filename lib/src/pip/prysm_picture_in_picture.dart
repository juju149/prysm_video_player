import 'package:flutter/services.dart';

import '../core/prysm_video_state.dart';

enum PrysmPictureInPictureSupport {
  unsupported,
  backendManaged,
  platformCustom,
}

class PrysmPictureInPictureState {
  const PrysmPictureInPictureState({
    this.support = PrysmPictureInPictureSupport.unsupported,
    this.enabled = false,
  });

  final PrysmPictureInPictureSupport support;
  final bool enabled;
}

abstract interface class PrysmPictureInPictureAdapter {
  Future<PrysmPictureInPictureState> state();

  Future<PrysmPictureInPictureState> enter(PrysmVideoState videoState);

  Future<PrysmPictureInPictureState> exit();
}

class PrysmNoopPictureInPictureAdapter implements PrysmPictureInPictureAdapter {
  const PrysmNoopPictureInPictureAdapter();

  @override
  Future<PrysmPictureInPictureState> state() async {
    return const PrysmPictureInPictureState();
  }

  @override
  Future<PrysmPictureInPictureState> enter(PrysmVideoState videoState) async {
    return const PrysmPictureInPictureState();
  }

  @override
  Future<PrysmPictureInPictureState> exit() async {
    return const PrysmPictureInPictureState();
  }
}

class PrysmPlatformPictureInPictureAdapter
    implements PrysmPictureInPictureAdapter {
  PrysmPlatformPictureInPictureAdapter({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('prysm_video_player/picture_in_picture');

  final MethodChannel _channel;

  @override
  Future<PrysmPictureInPictureState> state() async {
    return _call('state');
  }

  @override
  Future<PrysmPictureInPictureState> enter(PrysmVideoState videoState) async {
    return _call('enter', <String, Object?>{
      'positionMs': videoState.position.inMilliseconds,
      'durationMs': videoState.duration.inMilliseconds,
      'playing': videoState.playing,
      'live': videoState.live,
    });
  }

  @override
  Future<PrysmPictureInPictureState> exit() async {
    return _call('exit');
  }

  Future<PrysmPictureInPictureState> _call(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      return _mapState(result);
    } on MissingPluginException {
      return const PrysmPictureInPictureState();
    }
  }

  PrysmPictureInPictureState _mapState(Map<String, Object?>? result) {
    final supportName = result?['support'];
    final support = PrysmPictureInPictureSupport.values.firstWhere(
      (value) => value.name == supportName,
      orElse: () => PrysmPictureInPictureSupport.unsupported,
    );
    return PrysmPictureInPictureState(
      support: support,
      enabled: result?['enabled'] == true,
    );
  }
}

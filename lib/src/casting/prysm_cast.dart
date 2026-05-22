import 'package:flutter/services.dart';

import '../data_source/prysm_video_source.dart';

enum PrysmCastDeviceType { chromecast, airPlay, dlna, custom }

class PrysmCastDevice {
  const PrysmCastDevice({
    required this.id,
    required this.name,
    required this.type,
    this.available = true,
  });

  final String id;
  final String name;
  final PrysmCastDeviceType type;
  final bool available;
}

class PrysmCastSession {
  const PrysmCastSession({required this.device, this.active = false});

  final PrysmCastDevice device;
  final bool active;
}

abstract interface class PrysmCastAdapter {
  Future<List<PrysmCastDevice>> discover();

  Future<PrysmCastSession> start({
    required PrysmCastDevice device,
    required PrysmVideoSource source,
    Duration position = Duration.zero,
  });

  Future<void> updatePosition(Duration position);

  Future<void> stop();
}

class PrysmNoopCastAdapter implements PrysmCastAdapter {
  const PrysmNoopCastAdapter();

  @override
  Future<List<PrysmCastDevice>> discover() async {
    return const <PrysmCastDevice>[];
  }

  @override
  Future<PrysmCastSession> start({
    required PrysmCastDevice device,
    required PrysmVideoSource source,
    Duration position = Duration.zero,
  }) async {
    return PrysmCastSession(device: device);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> updatePosition(Duration position) async {}
}

class PrysmPlatformCastAdapter implements PrysmCastAdapter {
  PrysmPlatformCastAdapter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('prysm_video_player/cast');

  final MethodChannel _channel;

  @override
  Future<List<PrysmCastDevice>> discover() async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('discover');
      return raw
              ?.map(_mapDevice)
              .whereType<PrysmCastDevice>()
              .toList(growable: false) ??
          const <PrysmCastDevice>[];
    } on MissingPluginException {
      return const <PrysmCastDevice>[];
    }
  }

  @override
  Future<PrysmCastSession> start({
    required PrysmCastDevice device,
    required PrysmVideoSource source,
    Duration position = Duration.zero,
  }) async {
    try {
      final result = await _channel
          .invokeMapMethod<String, Object?>('start', <String, Object?>{
            'deviceId': device.id,
            'deviceType': device.type.name,
            'uri': source.uri,
            'title': source.title,
            'subtitle': source.subtitle,
            'poster': source.poster,
            'headers': source.headers,
            'positionMs': position.inMilliseconds,
          });
      return PrysmCastSession(
        device: device,
        active: result?['active'] == true,
      );
    } on MissingPluginException {
      return PrysmCastSession(device: device);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> updatePosition(Duration position) async {
    try {
      await _channel.invokeMethod<void>('updatePosition', <String, Object?>{
        'positionMs': position.inMilliseconds,
      });
    } on MissingPluginException {
      return;
    }
  }

  PrysmCastDevice? _mapDevice(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final typeName = raw['type'];
    if (id is! String || name is! String || typeName is! String) return null;
    final type = PrysmCastDeviceType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => PrysmCastDeviceType.custom,
    );
    return PrysmCastDevice(
      id: id,
      name: name,
      type: type,
      available: raw['available'] != false,
    );
  }
}

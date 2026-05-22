import 'prysm_video_cache_base.dart';
import 'prysm_video_cache_stub.dart'
    if (dart.library.io) 'prysm_video_cache_io.dart'
    as platform;

export 'prysm_video_cache_base.dart';

PrysmVideoCache createPrysmVideoCache() {
  return platform.createPrysmVideoCache();
}

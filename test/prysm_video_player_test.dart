import 'package:flutter_test/flutter_test.dart';
import 'package:prysm_video_player/prysm_video_player.dart';

void main() {
  group('PrysmVideoSource', () {
    test('normalizes asset paths for media_kit', () {
      final source = PrysmVideoSource.asset('assets/video.mp4');

      expect(source.type, PrysmVideoSourceType.asset);
      expect(source.resource, 'asset:///assets/video.mp4');
    });

    test('stores network metadata and headers', () {
      final source = PrysmVideoSource.network(
        'https://example.com/movie.m3u8',
        title: 'Movie',
        poster: 'https://example.com/poster.jpg',
        httpHeaders: {'Authorization': 'Bearer token'},
      );

      expect(source.type, PrysmVideoSourceType.network);
      expect(source.title, 'Movie');
      expect(source.poster, 'https://example.com/poster.jpg');
      expect(source.httpHeaders, {'Authorization': 'Bearer token'});
    });
  });

  group('PrysmVideoSnapshot', () {
    test('calculates clamped progress', () {
      const snapshot = PrysmVideoSnapshot(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 120),
        buffer: Duration(seconds: 60),
      );

      expect(snapshot.progress, 0.25);
      expect(snapshot.bufferProgress, 0.5);
    });
  });
}

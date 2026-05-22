class PrysmVideoQuality {
  const PrysmVideoQuality({
    required this.id,
    required this.label,
    this.height,
    this.width,
    this.bitrate,
    this.url,
    this.auto = false,
  });

  const PrysmVideoQuality.auto()
    : id = 'auto',
      label = 'Auto',
      height = null,
      width = null,
      bitrate = null,
      url = null,
      auto = true;

  factory PrysmVideoQuality.height(
    int height, {
    String? id,
    int? width,
    int? bitrate,
    String? url,
  }) {
    return PrysmVideoQuality(
      id: id ?? '${height}p',
      label: '${height}p',
      height: height,
      width: width,
      bitrate: bitrate,
      url: url,
    );
  }

  final String id;
  final String label;
  final int? height;
  final int? width;
  final int? bitrate;
  final String? url;
  final bool auto;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrysmVideoQuality &&
          other.id == id &&
          other.url == url &&
          other.height == height);

  @override
  int get hashCode => Object.hash(id, url, height);
}

class PrysmAudioTrack {
  const PrysmAudioTrack({
    required this.id,
    required this.label,
    this.languageCode,
    this.codec,
    this.bitrate,
    this.defaultTrack = false,
    this.audioDescription = false,
  });

  const PrysmAudioTrack.auto()
    : id = 'auto',
      label = 'Auto',
      languageCode = null,
      codec = null,
      bitrate = null,
      defaultTrack = false,
      audioDescription = false;

  const PrysmAudioTrack.off()
    : id = 'no',
      label = 'Off',
      languageCode = null,
      codec = null,
      bitrate = null,
      defaultTrack = false,
      audioDescription = false;

  final String id;
  final String label;
  final String? languageCode;
  final String? codec;
  final int? bitrate;
  final bool defaultTrack;
  final bool audioDescription;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PrysmAudioTrack && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class PrysmSubtitleTrackInfo {
  const PrysmSubtitleTrackInfo({
    required this.id,
    required this.label,
    this.languageCode,
    this.codec,
    this.external = false,
  });

  const PrysmSubtitleTrackInfo.auto()
    : id = 'auto',
      label = 'Auto',
      languageCode = null,
      codec = null,
      external = false;

  const PrysmSubtitleTrackInfo.off()
    : id = 'no',
      label = 'Off',
      languageCode = null,
      codec = null,
      external = false;

  final String id;
  final String label;
  final String? languageCode;
  final String? codec;
  final bool external;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrysmSubtitleTrackInfo && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class PrysmVideoTrack {
  const PrysmVideoTrack({
    required this.id,
    required this.label,
    this.width,
    this.height,
    this.codec,
    this.bitrate,
  });

  const PrysmVideoTrack.auto()
    : id = 'auto',
      label = 'Auto',
      width = null,
      height = null,
      codec = null,
      bitrate = null;

  const PrysmVideoTrack.off()
    : id = 'no',
      label = 'Off',
      width = null,
      height = null,
      codec = null,
      bitrate = null;

  final String id;
  final String label;
  final int? width;
  final int? height;
  final String? codec;
  final int? bitrate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PrysmVideoTrack && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class PrysmAvailableTracks {
  const PrysmAvailableTracks({
    this.video = const <PrysmVideoTrack>[
      PrysmVideoTrack.auto(),
      PrysmVideoTrack.off(),
    ],
    this.audio = const <PrysmAudioTrack>[
      PrysmAudioTrack.auto(),
      PrysmAudioTrack.off(),
    ],
    this.subtitles = const <PrysmSubtitleTrackInfo>[
      PrysmSubtitleTrackInfo.auto(),
      PrysmSubtitleTrackInfo.off(),
    ],
  });

  final List<PrysmVideoTrack> video;
  final List<PrysmAudioTrack> audio;
  final List<PrysmSubtitleTrackInfo> subtitles;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrysmAvailableTracks) return false;
    if (other.video.length != video.length ||
        other.audio.length != audio.length ||
        other.subtitles.length != subtitles.length) {
      return false;
    }
    for (var i = 0; i < video.length; i++) {
      if (other.video[i] != video[i]) return false;
    }
    for (var i = 0; i < audio.length; i++) {
      if (other.audio[i] != audio[i]) return false;
    }
    for (var i = 0; i < subtitles.length; i++) {
      if (other.subtitles[i] != subtitles[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(video),
    Object.hashAll(audio),
    Object.hashAll(subtitles),
  );
}

class PrysmSelectedTracks {
  const PrysmSelectedTracks({
    this.video = const PrysmVideoTrack.auto(),
    this.audio = const PrysmAudioTrack.auto(),
    this.subtitle = const PrysmSubtitleTrackInfo.auto(),
  });

  final PrysmVideoTrack video;
  final PrysmAudioTrack audio;
  final PrysmSubtitleTrackInfo subtitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrysmSelectedTracks &&
          other.video == video &&
          other.audio == audio &&
          other.subtitle == subtitle);

  @override
  int get hashCode => Object.hash(video, audio, subtitle);
}

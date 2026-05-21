import 'package:flutter/services.dart';

class PrysmDesktopShortcuts {
  PrysmDesktopShortcuts({
    Set<LogicalKeyboardKey>? playPause,
    this.seekBackward = LogicalKeyboardKey.arrowLeft,
    this.seekForward = LogicalKeyboardKey.arrowRight,
    this.volumeUp = LogicalKeyboardKey.arrowUp,
    this.volumeDown = LogicalKeyboardKey.arrowDown,
    this.fullscreen = LogicalKeyboardKey.keyF,
    this.mute = LogicalKeyboardKey.keyM,
    this.subtitles = LogicalKeyboardKey.keyS,
    this.escape = LogicalKeyboardKey.escape,
  }) : playPause =
           playPause ??
           <LogicalKeyboardKey>{
             LogicalKeyboardKey.space,
             LogicalKeyboardKey.keyK,
           };

  final Set<LogicalKeyboardKey> playPause;
  final LogicalKeyboardKey seekBackward;
  final LogicalKeyboardKey seekForward;
  final LogicalKeyboardKey volumeUp;
  final LogicalKeyboardKey volumeDown;
  final LogicalKeyboardKey fullscreen;
  final LogicalKeyboardKey mute;
  final LogicalKeyboardKey subtitles;
  final LogicalKeyboardKey escape;
}

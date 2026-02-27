import 'dart:async';
import 'package:just_audio/just_audio.dart';

String _noteAsset(String noteName) {
  final fname = noteName.replaceAll('#', 's');
  return 'assets/sounds/note_$fname.wav';
}

/// 曲目合成器：按音符顺序用 asset 文件逐拍播放
class SongSynthesizer {
  final AudioPlayer _player = AudioPlayer();
  bool _stopped = false;

  bool get isPlaying => _player.playing;

  /// 播放曲目
  /// [notes] 格式：List of (noteName, startTime, duration)，按 time 升序
  Future<void> play(List<({String note, double time, double duration})> notes) async {
    if (notes.isEmpty) return;
    _stopped = false;

    for (int i = 0; i < notes.length; i++) {
      if (_stopped) return;
      final n = notes[i];
      await _player.setAsset(_noteAsset(n.note));
      await _player.seek(Duration.zero);
      await _player.play();

      // 等到下一个音符的开始时间（或本音符结束）
      final nextTime = i + 1 < notes.length ? notes[i + 1].time : n.time + n.duration;
      final waitMs = ((nextTime - n.time) * 1000).round().clamp(50, 2000);
      await Future.delayed(Duration(milliseconds: waitMs));
    }
  }

  Future<void> stop() async {
    _stopped = true;
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}

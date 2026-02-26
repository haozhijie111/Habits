import 'dart:math';
import '../models/pitch_result.dart';
import '../models/score_note.dart';

/// 每 100ms 采样一帧的音高数据
class _PitchFrame {
  final double timestamp;
  final PitchResult pitch;
  const _PitchFrame(this.timestamp, this.pitch);
}

class ScoreComparator {
  // 评级阈值（cents）
  static const double _perfectThreshold = 25.0;
  static const double _goodThreshold = 50.0;

  final List<ScoreNote> scoreSheet; // 曲谱
  final List<_PitchFrame> _frames = [];

  ScoreComparator({required this.scoreSheet});

  /// 录制过程中每 100ms 调用一次，记录当前帧
  void addFrame(double timestamp, PitchResult pitch) {
    _frames.add(_PitchFrame(timestamp, pitch));
  }

  /// 录制结束后调用，返回完整评分结果
  SessionResult evaluate() {
    final judgements = scoreSheet.map(_judgeNote).toList();

    final perfect = judgements.where((j) => j.grade == NoteGrade.perfect).length;
    final good    = judgements.where((j) => j.grade == NoteGrade.good).length;
    final off     = judgements.where((j) => j.grade == NoteGrade.off).length;
    final missed  = judgements.where((j) => j.grade == NoteGrade.missed).length;
    final total   = judgements.length;

    // 加权得分：perfect=100, good=70, off=30, missed=0
    final rawScore = total == 0
        ? 0.0
        : (perfect * 100 + good * 70 + off * 30) / total;

    final accuracy = total == 0
        ? 0.0
        : (perfect + good) / total * 100;

    return SessionResult(
      judgements: judgements,
      totalNotes: total,
      perfectCount: perfect,
      goodCount: good,
      offCount: off,
      missedCount: missed,
      pitchScore: rawScore.clamp(0, 100),
      accuracyRate: accuracy,
    );
  }

  NoteJudgement _judgeNote(ScoreNote target) {
    // 取该音符时间窗口内的所有帧
    final windowFrames = _frames.where((f) =>
        f.timestamp >= target.time &&
        f.timestamp < target.time + target.duration).toList();

    if (windowFrames.isEmpty) {
      return NoteJudgement(
        target: target,
        playedNote: null,
        avgCentsOffset: 0,
        hitRate: 0,
        grade: NoteGrade.missed,
      );
    }

    // 有声音的帧（置信度 > 0.1）
    final activeFrames = windowFrames
        .where((f) => f.pitch.confidence > 0.1)
        .toList();

    if (activeFrames.isEmpty) {
      return NoteJudgement(
        target: target,
        playedNote: null,
        avgCentsOffset: 0,
        hitRate: 0,
        grade: NoteGrade.missed,
      );
    }

    // 找出出现最多的音符名称
    final noteCount = <String, int>{};
    for (final f in activeFrames) {
      noteCount[f.pitch.noteName] = (noteCount[f.pitch.noteName] ?? 0) + 1;
    }
    final dominantNote = noteCount.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    // 计算与目标音符的平均 cents 偏移
    final targetMidi = _noteToMidi(target.note);
    final avgOffset = activeFrames.map((f) {
      final playedMidi = _noteToMidi(f.pitch.noteName);
      // 半音差转 cents，再加上精细偏移
      return (playedMidi - targetMidi) * 100.0 + f.pitch.centsOffset;
    }).reduce((a, b) => a + b) / activeFrames.length;

    final hitRate = activeFrames.length / windowFrames.length;
    final absOffset = avgOffset.abs();

    NoteGrade grade;
    if (dominantNote != target.note) {
      grade = NoteGrade.off; // 音符完全错误
    } else if (absOffset <= _perfectThreshold) {
      grade = NoteGrade.perfect;
    } else if (absOffset <= _goodThreshold) {
      grade = NoteGrade.good;
    } else {
      grade = NoteGrade.off;
    }

    return NoteJudgement(
      target: target,
      playedNote: dominantNote,
      avgCentsOffset: avgOffset,
      hitRate: hitRate,
      grade: grade,
    );
  }

  /// 音符名称 -> MIDI 编号（如 "A4" -> 69）
  static int _noteToMidi(String noteName) {
    const noteMap = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11,
    };
    // 解析音符名，如 "F#4" -> note="F#", octave=4
    final match = RegExp(r'^([A-G]#?)(\d+)$').firstMatch(noteName);
    if (match == null) return 60;
    final note = match.group(1)!;
    final octave = int.parse(match.group(2)!);
    return (octave + 1) * 12 + (noteMap[note] ?? 0);
  }
}

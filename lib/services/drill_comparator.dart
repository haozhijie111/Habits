import '../models/drill_lesson.dart';
import '../models/pitch_result.dart';

class _Frame {
  final double timestamp;
  final PitchResult pitch;
  const _Frame(this.timestamp, this.pitch);
}

class DrillComparator {
  static const double _perfectCents = 25.0;
  static const double _goodCents = 50.0;

  final DrillLesson lesson;
  final List<_Frame> _frames = [];

  DrillComparator({required this.lesson});

  void addFrame(double timestamp, PitchResult pitch) {
    _frames.add(_Frame(timestamp, pitch));
  }

  DrillResult evaluate() {
    final judgements = lesson.beats.map(_judgeBeat).toList();

    final perfect = judgements.where((j) => j.grade == BeatGrade.perfect).length;
    final good    = judgements.where((j) => j.grade == BeatGrade.good).length;
    final missed  = judgements.where((j) => j.grade == BeatGrade.missed).length;
    final total   = judgements.length;

    // 音准分：基于 cents 偏移
    final pitchScore = total == 0
        ? 0.0
        : (perfect * 100 + good * 70 +
               judgements
                   .where((j) => j.grade == BeatGrade.off)
                   .length *
                   30) /
              total;

    // 节奏分：有声音的拍子占比
    final soundBeats = judgements.where((j) => j.hasSound).length;
    final rhythmScore = total == 0 ? 0.0 : soundBeats / total * 100;

    // 综合分：音准 60% + 节奏 40%
    final totalScore = pitchScore * 0.6 + rhythmScore * 0.4;
    final accuracy = total == 0 ? 0.0 : (perfect + good) / total * 100;

    return DrillResult(
      lesson: lesson,
      judgements: judgements,
      pitchScore: pitchScore.clamp(0, 100),
      rhythmScore: rhythmScore.clamp(0, 100),
      totalScore: totalScore.clamp(0, 100),
      accuracyRate: accuracy,
    );
  }

  BeatJudgement _judgeBeat(ScoreBeat beat) {
    final window = _frames
        .where((f) =>
            f.timestamp >= beat.time &&
            f.timestamp < beat.time + beat.duration)
        .toList();

    if (window.isEmpty) {
      return BeatJudgement(
        target: beat,
        playedNote: null,
        avgCentsOffset: 0,
        hasSound: false,
        grade: BeatGrade.missed,
      );
    }

    final active = window.where((f) => f.pitch.confidence > 0.1).toList();
    final hasSound = active.length / window.length > 0.3;

    if (!hasSound) {
      return BeatJudgement(
        target: beat,
        playedNote: null,
        avgCentsOffset: 0,
        hasSound: false,
        grade: BeatGrade.missed,
      );
    }

    // 主音符
    final noteCount = <String, int>{};
    for (final f in active) {
      noteCount[f.pitch.noteName] = (noteCount[f.pitch.noteName] ?? 0) + 1;
    }
    final dominant = noteCount.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    // 平均 cents 偏移（相对目标音符）
    final targetMidi = _noteToMidi(beat.note);
    final avgOffset = active.map((f) {
      final playedMidi = _noteToMidi(f.pitch.noteName);
      return (playedMidi - targetMidi) * 100.0 + f.pitch.centsOffset;
    }).reduce((a, b) => a + b) /
        active.length;

    BeatGrade grade;
    if (dominant != beat.note) {
      grade = BeatGrade.off;
    } else if (avgOffset.abs() <= _perfectCents) {
      grade = BeatGrade.perfect;
    } else if (avgOffset.abs() <= _goodCents) {
      grade = BeatGrade.good;
    } else {
      grade = BeatGrade.off;
    }

    return BeatJudgement(
      target: beat,
      playedNote: dominant,
      avgCentsOffset: avgOffset,
      hasSound: true,
      grade: grade,
    );
  }

  static int _noteToMidi(String name) {
    const map = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11,
    };
    final m = RegExp(r'^([A-G]#?)(\d+)$').firstMatch(name);
    if (m == null) return 60;
    return (int.parse(m.group(2)!) + 1) * 12 + (map[m.group(1)!] ?? 0);
  }
}

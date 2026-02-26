/// 节奏型枚举
enum RhythmPattern {
  allShort,      // 全短音（8个短音）
  shortLong,     // 短短短长（4短1长）
  longShort,     // 长短长短
  dotted,        // 附点节奏
  syncopation,   // 切分节奏
}

/// 专项练习课程
class DrillLesson {
  final String id;
  final String title;
  final String subtitle;       // 如 "8个短音"
  final String description;
  final RhythmPattern pattern;
  final String targetNote;     // 练习音符，如 "G4"
  final List<ScoreBeat> beats; // 节拍序列
  final int bpm;               // 速度

  const DrillLesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.pattern,
    required this.targetNote,
    required this.beats,
    required this.bpm,
  });

  /// 总时长（秒）
  double get totalDuration => beats.isEmpty ? 0 : beats.last.time + beats.last.duration;
}

/// 单个节拍
class ScoreBeat {
  final double time;       // 开始时间（秒）
  final String note;       // 音符
  final double duration;   // 持续时长（秒）
  final BeatType type;     // 短/长

  const ScoreBeat({
    required this.time,
    required this.note,
    required this.duration,
    required this.type,
  });
}

enum BeatType { short, long }

/// 专项练习结果
class DrillResult {
  final DrillLesson lesson;
  final List<BeatJudgement> judgements;
  final double pitchScore;     // 音准分 0~100
  final double rhythmScore;    // 节奏分 0~100
  final double totalScore;     // 综合分
  final double accuracyRate;

  const DrillResult({
    required this.lesson,
    required this.judgements,
    required this.pitchScore,
    required this.rhythmScore,
    required this.totalScore,
    required this.accuracyRate,
  });
}

/// 单拍判定结果
class BeatJudgement {
  final ScoreBeat target;
  final String? playedNote;
  final double avgCentsOffset;
  final bool hasSound;         // 是否有声音（节奏判定）
  final BeatGrade grade;

  const BeatJudgement({
    required this.target,
    required this.playedNote,
    required this.avgCentsOffset,
    required this.hasSound,
    required this.grade,
  });
}

enum BeatGrade { perfect, good, off, missed }

/// 曲谱中的单个音符节点
class ScoreNote {
  final double time;   // 出现时间（秒）
  final String note;   // 目标音符，如 "G4"
  final double duration; // 持续时长（秒）

  const ScoreNote({
    required this.time,
    required this.note,
    required this.duration,
  });

  factory ScoreNote.fromJson(Map<String, dynamic> json) => ScoreNote(
        time: (json['time'] as num).toDouble(),
        note: json['note'] as String,
        duration: (json['duration'] as num?)?.toDouble() ?? 0.5,
      );

  Map<String, dynamic> toJson() => {
        'time': time,
        'note': note,
        'duration': duration,
      };
}

/// 单个音符的比对结果
class NoteJudgement {
  final ScoreNote target;       // 目标音符
  final String? playedNote;     // 实际吹奏音符（null = 未检测到声音）
  final double avgCentsOffset;  // 平均 cents 偏移
  final double hitRate;         // 命中率 0.0~1.0（有效帧占比）
  final NoteGrade grade;        // 评级

  const NoteJudgement({
    required this.target,
    required this.playedNote,
    required this.avgCentsOffset,
    required this.hitRate,
    required this.grade,
  });

  bool get isMissed => playedNote == null;
}

enum NoteGrade { perfect, good, off, missed }

/// 完整录制结束后的总评结果
class SessionResult {
  final List<NoteJudgement> judgements;
  final int totalNotes;
  final int perfectCount;
  final int goodCount;
  final int offCount;
  final int missedCount;
  final double pitchScore;    // 音准分 0~100
  final double accuracyRate;  // 正确率百分比

  const SessionResult({
    required this.judgements,
    required this.totalNotes,
    required this.perfectCount,
    required this.goodCount,
    required this.offCount,
    required this.missedCount,
    required this.pitchScore,
    required this.accuracyRate,
  });
}

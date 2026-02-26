import 'drill_lesson.dart';

/// 内置专项练习课程库
class DrillLibrary {
  DrillLibrary._();

  static List<DrillLesson> get all => [
        lesson8Short,
        lesson4ShortLong,
        lessonLongShort,
        lessonDotted,
        lessonSyncopation,
      ];

  // ── 1. 8个短音 ────────────────────────────────────────────────────────────
  static final lesson8Short = DrillLesson(
    id: 'drill_8short',
    title: '8个短音',
    subtitle: '♩♩♩♩♩♩♩♩',
    description: '连续吹奏8个均等短音，训练气息均匀与音头清晰',
    pattern: RhythmPattern.allShort,
    targetNote: 'G4',
    bpm: 80,
    beats: _buildBeats('G4', [
      (0.0, 0.4, BeatType.short),
      (0.5, 0.4, BeatType.short),
      (1.0, 0.4, BeatType.short),
      (1.5, 0.4, BeatType.short),
      (2.0, 0.4, BeatType.short),
      (2.5, 0.4, BeatType.short),
      (3.0, 0.4, BeatType.short),
      (3.5, 0.4, BeatType.short),
    ]),
  );

  // ── 2. 4短1长 ─────────────────────────────────────────────────────────────
  static final lesson4ShortLong = DrillLesson(
    id: 'drill_4short1long',
    title: '4短一长',
    subtitle: '♩♩♩♩♩—',
    description: '4个短音接1个长音，训练气息控制与音符时值',
    pattern: RhythmPattern.shortLong,
    targetNote: 'G4',
    bpm: 80,
    beats: _buildBeats('G4', [
      (0.0, 0.4, BeatType.short),
      (0.5, 0.4, BeatType.short),
      (1.0, 0.4, BeatType.short),
      (1.5, 0.4, BeatType.short),
      (2.0, 1.8, BeatType.long),
    ]),
  );

  // ── 3. 长短交替 ───────────────────────────────────────────────────────────
  static final lessonLongShort = DrillLesson(
    id: 'drill_longshort',
    title: '长短交替',
    subtitle: '♩— ♩ ♩— ♩',
    description: '长短交替节奏，训练音符时值对比',
    pattern: RhythmPattern.longShort,
    targetNote: 'A4',
    bpm: 72,
    beats: _buildBeats('A4', [
      (0.0, 0.8, BeatType.long),
      (1.0, 0.4, BeatType.short),
      (1.5, 0.8, BeatType.long),
      (2.5, 0.4, BeatType.short),
      (3.0, 0.8, BeatType.long),
      (4.0, 0.4, BeatType.short),
    ]),
  );

  // ── 4. 附点节奏 ───────────────────────────────────────────────────────────
  static final lessonDotted = DrillLesson(
    id: 'drill_dotted',
    title: '附点节奏',
    subtitle: '♩. ♪ ♩. ♪',
    description: '附点四分音符接八分音符，训练附点节奏感',
    pattern: RhythmPattern.dotted,
    targetNote: 'D5',
    bpm: 76,
    beats: _buildBeats('D5', [
      (0.0, 0.6, BeatType.long),
      (0.75, 0.2, BeatType.short),
      (1.0, 0.6, BeatType.long),
      (1.75, 0.2, BeatType.short),
      (2.0, 0.6, BeatType.long),
      (2.75, 0.2, BeatType.short),
      (3.0, 0.6, BeatType.long),
      (3.75, 0.2, BeatType.short),
    ]),
  );

  // ── 5. 切分节奏 ───────────────────────────────────────────────────────────
  static final lessonSyncopation = DrillLesson(
    id: 'drill_syncopation',
    title: '切分节奏',
    subtitle: '♪ ♩ ♪',
    description: '短长短切分节奏，训练重音位移感',
    pattern: RhythmPattern.syncopation,
    targetNote: 'E4',
    bpm: 72,
    beats: _buildBeats('E4', [
      (0.0, 0.25, BeatType.short),
      (0.25, 0.5, BeatType.long),
      (0.75, 0.25, BeatType.short),
      (1.0, 0.25, BeatType.short),
      (1.25, 0.5, BeatType.long),
      (1.75, 0.25, BeatType.short),
      (2.0, 0.25, BeatType.short),
      (2.25, 0.5, BeatType.long),
      (2.75, 0.25, BeatType.short),
    ]),
  );

  static List<ScoreBeat> _buildBeats(
    String note,
    List<(double, double, BeatType)> data,
  ) =>
      data
          .map((e) => ScoreBeat(
                time: e.$1,
                note: note,
                duration: e.$2,
                type: e.$3,
              ))
          .toList();
}

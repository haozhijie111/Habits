import 'score_note.dart';

class Song {
  final String id;
  final String title;
  final String emoji;
  final int bpm;
  final List<ScoreNote> notes;

  const Song({
    required this.id,
    required this.title,
    required this.emoji,
    required this.bpm,
    required this.notes,
  });

  double get totalDuration =>
      notes.isEmpty ? 0 : notes.last.time + notes.last.duration;
}

class SongLibrary {
  SongLibrary._();

  static List<Song> get all => [twinkleTwinkle, happyNewYear, redRiver];

  // ── 1. 小星星（D调）────────────────────────────────────────────────────────
  static const twinkleTwinkle = Song(
    id: 'twinkle',
    title: '小星星',
    emoji: '⭐',
    bpm: 90,
    notes: [
      ScoreNote(time: 0.0,  note: 'D4', duration: 0.5),
      ScoreNote(time: 0.5,  note: 'D4', duration: 0.5),
      ScoreNote(time: 1.0,  note: 'A4', duration: 0.5),
      ScoreNote(time: 1.5,  note: 'A4', duration: 0.5),
      ScoreNote(time: 2.0,  note: 'B4', duration: 0.5),
      ScoreNote(time: 2.5,  note: 'B4', duration: 0.5),
      ScoreNote(time: 3.0,  note: 'A4', duration: 1.0),
      ScoreNote(time: 4.0,  note: 'G4', duration: 0.5),
      ScoreNote(time: 4.5,  note: 'G4', duration: 0.5),
      ScoreNote(time: 5.0,  note: 'F#4', duration: 0.5),
      ScoreNote(time: 5.5,  note: 'F#4', duration: 0.5),
      ScoreNote(time: 6.0,  note: 'E4', duration: 0.5),
      ScoreNote(time: 6.5,  note: 'E4', duration: 0.5),
      ScoreNote(time: 7.0,  note: 'D4', duration: 1.0),
    ],
  );

  // ── 2. 新年好（C调，竹笛筒音作5，3/4拍）────────────────────────────────────
  // 谱：5 3 5 | 5 3 5 | 6 6 6 5 6 | 5 - - |
  //     5 5 6 5 | 3 - - | 4 4 4 3 4 | 3 - - |
  // bpm=100，每拍=0.6s，每小节=1.8s
  // C调：1=C4 2=D4 3=E4 4=F4 5=G4 6=A4 7=B4
  static const happyNewYear = Song(
    id: 'happy_new_year',
    title: '新年好',
    emoji: '🎉',
    bpm: 100,
    notes: [
      // 小节1：5 3 5
      ScoreNote(time: 0.0,  note: 'G4', duration: 0.6),
      ScoreNote(time: 0.6,  note: 'E4', duration: 0.6),
      ScoreNote(time: 1.2,  note: 'G4', duration: 0.6),
      // 小节2：5 3 5
      ScoreNote(time: 1.8,  note: 'G4', duration: 0.6),
      ScoreNote(time: 2.4,  note: 'E4', duration: 0.6),
      ScoreNote(time: 3.0,  note: 'G4', duration: 0.6),
      // 小节3：6 6 6 5 6（一拍三连音 + 两个四分音符）
      ScoreNote(time: 3.6,  note: 'A4', duration: 0.2),
      ScoreNote(time: 3.8,  note: 'A4', duration: 0.2),
      ScoreNote(time: 4.0,  note: 'A4', duration: 0.2),
      ScoreNote(time: 4.2,  note: 'G4', duration: 0.6),
      ScoreNote(time: 4.8,  note: 'A4', duration: 0.6),
      // 小节4：5 - -（附点二分音符）
      ScoreNote(time: 5.4,  note: 'G4', duration: 1.8),
      // 小节5：5 5 6 5
      ScoreNote(time: 7.2,  note: 'G4', duration: 0.6),
      ScoreNote(time: 7.8,  note: 'G4', duration: 0.6),
      ScoreNote(time: 8.4,  note: 'A4', duration: 0.6),
      ScoreNote(time: 9.0,  note: 'G4', duration: 0.6),
      // 小节6：3 - -
      ScoreNote(time: 9.6,  note: 'E4', duration: 1.8),
      // 小节7：4 4 4 3 4（一拍三连音 + 两个四分音符）
      ScoreNote(time: 11.4, note: 'F4', duration: 0.2),
      ScoreNote(time: 11.6, note: 'F4', duration: 0.2),
      ScoreNote(time: 11.8, note: 'F4', duration: 0.2),
      ScoreNote(time: 12.0, note: 'E4', duration: 0.6),
      ScoreNote(time: 12.6, note: 'F4', duration: 0.6),
      // 小节8：3 - -
      ScoreNote(time: 13.2, note: 'E4', duration: 1.8),
    ],
  );

  // ── 3. 红河谷（G调）──────────────────────────────────────────────────────────
  // 经典旋律：请来吧，到那红河谷
  // 谱：3 5 5 | 6 5 6 1' | 5 - 3 5 | 6 5 3 2 | 1 - - |
  //     3 5 5 | 6 5 6 1' | 5 - 3 5 | 6 5 3 2 | 1 - - |
  static const redRiver = Song(
    id: 'red_river',
    title: '红河谷',
    emoji: '🌾',
    bpm: 80,
    notes: [
      // 第一句
      ScoreNote(time: 0.0,  note: 'E4', duration: 0.5),
      ScoreNote(time: 0.5,  note: 'G4', duration: 0.5),
      ScoreNote(time: 1.0,  note: 'G4', duration: 0.5),
      ScoreNote(time: 1.5,  note: 'A4', duration: 0.5),
      ScoreNote(time: 2.0,  note: 'G4', duration: 0.5),
      ScoreNote(time: 2.5,  note: 'A4', duration: 0.5),
      ScoreNote(time: 3.0,  note: 'C5', duration: 1.0),
      // 第二句
      ScoreNote(time: 4.0,  note: 'G4', duration: 1.0),
      ScoreNote(time: 5.0,  note: 'E4', duration: 0.5),
      ScoreNote(time: 5.5,  note: 'G4', duration: 0.5),
      ScoreNote(time: 6.0,  note: 'A4', duration: 0.5),
      ScoreNote(time: 6.5,  note: 'G4', duration: 0.5),
      ScoreNote(time: 7.0,  note: 'E4', duration: 0.5),
      ScoreNote(time: 7.5,  note: 'D4', duration: 0.5),
      ScoreNote(time: 8.0,  note: 'C4', duration: 1.5),
      // 第三句（重复第一句）
      ScoreNote(time: 9.5,  note: 'E4', duration: 0.5),
      ScoreNote(time: 10.0, note: 'G4', duration: 0.5),
      ScoreNote(time: 10.5, note: 'G4', duration: 0.5),
      ScoreNote(time: 11.0, note: 'A4', duration: 0.5),
      ScoreNote(time: 11.5, note: 'G4', duration: 0.5),
      ScoreNote(time: 12.0, note: 'A4', duration: 0.5),
      ScoreNote(time: 12.5, note: 'C5', duration: 1.0),
      // 第四句（结尾）
      ScoreNote(time: 13.5, note: 'G4', duration: 1.0),
      ScoreNote(time: 14.5, note: 'E4', duration: 0.5),
      ScoreNote(time: 15.0, note: 'G4', duration: 0.5),
      ScoreNote(time: 15.5, note: 'A4', duration: 0.5),
      ScoreNote(time: 16.0, note: 'G4', duration: 0.5),
      ScoreNote(time: 16.5, note: 'E4', duration: 0.5),
      ScoreNote(time: 17.0, note: 'D4', duration: 0.5),
      ScoreNote(time: 17.5, note: 'C4', duration: 2.0),
    ],
  );
}

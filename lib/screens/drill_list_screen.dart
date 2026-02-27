import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/drill_lesson.dart';
import '../models/drill_library.dart';
import '../providers/drill_session_provider.dart';
import 'drill_practice_screen.dart';

// 合成单音 WAV（复用 flute_keyboard_screen 的逻辑）
Uint8List _synthNoteWav(String noteName, double duration) {
  const sr = 22050;
  double _freq(String n) {
    const m = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final r = RegExp(r'^([A-G][#b]?)(\d)$').firstMatch(n);
    if (r == null) return 440.0;
    final midi = (int.parse(r.group(2)!) + 1) * 12 + (m[r.group(1)!] ?? 0);
    return 440.0 * math.pow(2, (midi - 69) / 12);
  }
  final freq = _freq(noteName);
  final n = (duration * sr).round();
  final fade = (sr * 0.015).round();
  final s = List<double>.filled(n, 0.0);
  for (int i = 0; i < n; i++) {
    double a = 0.55;
    if (i < fade) a *= i / fade;
    if (i > n - fade) a *= (n - i) / fade;
    s[i] = a * (0.55 * math.sin(2 * math.pi * freq * i / sr) +
        0.28 * math.sin(4 * math.pi * freq * i / sr) +
        0.12 * math.sin(6 * math.pi * freq * i / sr) +
        0.05 * math.sin(8 * math.pi * freq * i / sr));
  }
  final ds = n * 2;
  final b = ByteData(44 + ds);
  for (final e in {0: 0x52, 1: 0x49, 2: 0x46, 3: 0x46}.entries) { b.setUint8(e.key, e.value); }
  b.setUint32(4, 36 + ds, Endian.little);
  for (final e in {8: 0x57, 9: 0x41, 10: 0x56, 11: 0x45}.entries) { b.setUint8(e.key, e.value); }
  for (final e in {12: 0x66, 13: 0x6D, 14: 0x74, 15: 0x20}.entries) { b.setUint8(e.key, e.value); }
  b.setUint32(16, 16, Endian.little); b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little); b.setUint32(24, sr, Endian.little);
  b.setUint32(28, sr * 2, Endian.little); b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  for (final e in {36: 0x64, 37: 0x61, 38: 0x74, 39: 0x61}.entries) { b.setUint8(e.key, e.value); }
  b.setUint32(40, ds, Endian.little);
  for (int i = 0; i < n; i++) {
    b.setInt16(44 + i * 2, (s[i] * 32767).clamp(-32768, 32767).toInt(), Endian.little);
  }
  return b.buffer.asUint8List();
}


class DrillListScreen extends ConsumerWidget {
  const DrillListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = DrillLibrary.all;

    return Scaffold(
      backgroundColor: KidColors.bg,
      appBar: AppBar(
        backgroundColor: KidColors.bg,
        automaticallyImplyLeading: false,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏋️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 6),
            Text('专项练习',
                style: TextStyle(
                    color: KidColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              '选一个练习，开始吹吧！🎵',
              style: TextStyle(
                  color: KidColors.textMid,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: lessons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _LessonCard(
                lesson: lessons[i],
                index: i,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LessonCard extends ConsumerStatefulWidget {
  final DrillLesson lesson;
  final int index;
  const _LessonCard({required this.lesson, required this.index});

  @override
  ConsumerState<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends ConsumerState<_LessonCard> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _previewTimer;
  bool _previewing = false;
  int _previewBeat = 0;

  @override
  void dispose() {
    _previewTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    if (_previewing) {
      _stopPreview();
      return;
    }
    setState(() { _previewing = true; _previewBeat = 0; });

    final beats = widget.lesson.beats;
    final bpm = widget.lesson.bpm;
    final beatDuration = Duration(milliseconds: (60000 / bpm).round());

    Future<void> playNext() async {
      if (!_previewing || _previewBeat >= beats.length) {
        _stopPreview();
        return;
      }
      final beat = beats[_previewBeat];
      final wav = _synthNoteWav(beat.note, beat.duration.clamp(0.1, 0.8));
      try {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/preview_beat.wav');
        await file.writeAsBytes(wav);
        await _player.setFilePath(file.path);
        await _player.seek(Duration.zero);
        await _player.play();
      } catch (_) {}
      setState(() => _previewBeat++);
      _previewTimer = Timer(beatDuration, playNext);
    }
    playNext();
  }

  void _stopPreview() {
    _previewTimer?.cancel();
    _player.stop();
    if (mounted) setState(() { _previewing = false; _previewBeat = 0; });
  }

  static const _emojis = ['🎵', '🎶', '🎼', '🎹', '🎸'];
  static const _cardColors = [
    Color(0xFFFFECE0),
    Color(0xFFE0F7F4),
    Color(0xFFF3E5FF),
    Color(0xFFFFF8DC),
    Color(0xFFFFE4EE),
  ];
  static const _borderColors = [
    KidColors.primary,
    KidColors.secondary,
    KidColors.purple,
    Color(0xFFFFB300),
    KidColors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final i = widget.index;
    final lesson = widget.lesson;
    final color = _cardColors[i % _cardColors.length];
    final border = _borderColors[i % _borderColors.length];
    final emoji = _emojis[i % _emojis.length];

    return GestureDetector(
      onTap: () {
        _stopPreview();
        ref.read(drillSessionProvider.notifier).selectLesson(lesson);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DrillPracticeScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: border.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // 大 emoji 图标
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: border.withValues(alpha: 0.2), blurRadius: 6)
                ],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: const TextStyle(
                      color: KidColors.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lesson.subtitle,
                    style: TextStyle(
                      color: border,
                      fontSize: 16,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lesson.description,
                    style: const TextStyle(color: KidColors.textMid, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: border.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lesson.targetNote,
                    style: TextStyle(
                      color: border,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lesson.bpm} BPM',
                  style: const TextStyle(color: KidColors.textLight, fontSize: 11),
                ),
                const SizedBox(height: 6),
                // 试听按钮
                GestureDetector(
                  onTap: _togglePreview,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _previewing ? border : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        _previewing ? '⏹' : '🔊',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
